import httpx
import pytest

from executor.actions import ActionError
from tests.helpers import (FULL_TARGET, TARGET, FakeContainer, FakeDocker, FakeImage, make_actions,
                           sample_app_transport)


def test_restart_waits_until_health_answers():
    attempts = []

    def handler(request):
        attempts.append(request)
        if len(attempts) < 3:
            raise httpx.ConnectError("starting")
        return httpx.Response(200)

    actions = make_actions(transport=httpx.MockTransport(handler))

    assert actions.restart(TARGET)["container"] == "dc-sample-app"
    assert len(attempts) == 3


def test_restart_fails_when_service_never_becomes_healthy():
    actions = make_actions(transport=httpx.MockTransport(lambda r: httpx.Response(503)), health_timeout_seconds=0)

    with pytest.raises(ActionError, match="not healthy"):
        actions.restart(TARGET)


def test_circuit_breaker_retries_connection_errors():
    transport, calls = sample_app_transport(breaker_statuses=[httpx.ConnectError("down"), 200])

    assert make_actions(transport=transport).open_circuit_breaker(TARGET) == {
        "breaker_open": True, "attempts": 2, "instances": 1}
    assert len(calls) == 2


def test_circuit_breaker_does_not_retry_client_errors():
    transport, calls = sample_app_transport(breaker_statuses=[422])

    with pytest.raises(ActionError, match="HTTP 422"):
        make_actions(transport=transport).open_circuit_breaker(TARGET)
    assert len(calls) == 1


def test_unknown_action_is_refused():
    with pytest.raises(ActionError, match="not implemented"):
        make_actions().run("shell", TARGET)


# --- health checks go to one container, not the shared alias ------------------------

def test_health_is_checked_on_the_container_name():
    transport, calls = sample_app_transport()
    make_actions(transport=transport).restart(TARGET)

    assert [str(c.url) for c in calls] == ["http://dc-sample-app:8000/health"]


def add_replicas(docker_client, count):
    for index in range(2, 2 + count):
        name = f"dc-sample-app-{index}"
        docker_client.by_name[name] = FakeContainer(
            docker_client, name, labels={"dc.executor.replica-of": "sample-app", "logging": "promtail"})


def test_restart_and_breaker_cover_every_replica():
    docker_client = FakeDocker()
    add_replicas(docker_client, 2)
    transport, calls = sample_app_transport(breaker_statuses=[200, 200, 200])
    actions = make_actions(docker_client=docker_client, transport=transport)

    assert actions.restart(FULL_TARGET)["instances"] == 3
    assert [e for e in docker_client.log if e[0] == "restart"] == [
        ("restart", "dc-sample-app"), ("restart", "dc-sample-app-2"), ("restart", "dc-sample-app-3")]
    assert actions.open_circuit_breaker(FULL_TARGET)["instances"] == 3
    assert {c.url.host for c in calls if c.url.path == "/admin/circuit-breaker"} == {
        "dc-sample-app", "dc-sample-app-2", "dc-sample-app-3"}


# --- rollback ------------------------------------------------------------------------

def test_rollback_recreates_the_container_from_the_rollback_image():
    docker_client = FakeDocker()
    old = docker_client.by_name["dc-sample-app"]

    detail = make_actions(docker_client=docker_client).rollback(FULL_TARGET)

    assert detail["changed"] is True
    assert detail["image"] == "dc-sample-app:stable"
    assert detail["previous_image"] == "dc-sample-app:dev"
    new = docker_client.by_name["dc-sample-app"]
    assert new is not old and new.status == "running"
    assert new.image.id == "sha256:stable"
    assert old.removed is True
    kwargs = new.create_kwargs
    # Only the container's own environment is copied, not the old image's release settings.
    assert kwargs["environment"] == ["SERVICE_NAME=sample-app"]
    assert kwargs["labels"]["com.docker.compose.service"] == "sample-app"  # `docker compose exec` still works
    assert kwargs["networking_config"]["dc-monitoring_default"]["Aliases"] == ["sample-app"]
    assert kwargs["restart_policy"] == {"Name": "unless-stopped"}
    assert "command" not in kwargs  # same as the image default
    assert [e[0] for e in docker_client.log] == ["stop", "rename", "create", "start", "remove"]


def test_rollback_restores_the_old_container_when_the_new_one_is_unhealthy():
    docker_client = FakeDocker()
    old = docker_client.by_name["dc-sample-app"]
    actions = make_actions(docker_client=docker_client, transport=httpx.MockTransport(lambda r: httpx.Response(503)),
                           health_timeout_seconds=0)

    with pytest.raises(ActionError, match="previous container was restored"):
        actions.rollback(FULL_TARGET)

    assert docker_client.by_name["dc-sample-app"] is old
    assert old.status == "running" and old.removed is False
    assert docker_client.created[0].removed is True


def test_rollback_restores_the_old_container_when_create_fails():
    docker_client = FakeDocker()
    docker_client.fail_on = ("create", "dc-sample-app")
    old = docker_client.by_name["dc-sample-app"]

    with pytest.raises(ActionError, match="restored"):
        make_actions(docker_client=docker_client).rollback(FULL_TARGET)

    assert docker_client.by_name["dc-sample-app"] is old and old.status == "running"


def test_rollback_is_a_no_op_when_already_on_the_rollback_image():
    docker_client = FakeDocker()
    docker_client.by_name["dc-sample-app"] = FakeContainer(docker_client, "dc-sample-app", image_ref="dc-sample-app:stable")

    detail = make_actions(docker_client=docker_client).rollback(FULL_TARGET)

    assert detail["changed"] is False
    assert docker_client.log == []


def test_rollback_fails_cleanly_when_the_image_is_missing():
    docker_client = FakeDocker(images={"dc-sample-app:dev": FakeImage("sha256:dev")})

    with pytest.raises(ActionError, match="does not exist"):
        make_actions(docker_client=docker_client).rollback(FULL_TARGET)
    assert docker_client.log == []


def test_rollback_also_replaces_replicas():
    docker_client = FakeDocker()
    add_replicas(docker_client, 1)

    detail = make_actions(docker_client=docker_client).rollback(FULL_TARGET)

    assert detail["instances"] == 2
    replica = docker_client.by_name["dc-sample-app-2"]
    assert replica.image.id == "sha256:stable"
    assert replica.create_kwargs["labels"]["dc.executor.replica-of"] == "sample-app"


# --- scale ---------------------------------------------------------------------------

def test_scale_adds_replicas_up_to_max():
    docker_client = FakeDocker()
    transport, calls = sample_app_transport()

    detail = make_actions(docker_client=docker_client, transport=transport).scale(FULL_TARGET)

    assert detail == {"service_name": "sample-app", "instances_before": 1, "instances_after": 3,
                      "added": ["dc-sample-app-2", "dc-sample-app-3"], "image": "dc-sample-app:dev"}
    replica = docker_client.by_name["dc-sample-app-2"]
    assert replica.status == "running"
    labels = replica.create_kwargs["labels"]
    assert labels["dc.executor.replica-of"] == "sample-app"
    assert labels["com.docker.compose.service"] == "sample-app"  # Promtail's `service` label
    assert "com.docker.compose.project" not in labels  # docker compose must not adopt or remove it
    assert replica.create_kwargs["networking_config"]["dc-monitoring_default"]["Aliases"] == ["sample-app"]
    assert {c.url.host for c in calls} == {"dc-sample-app-2", "dc-sample-app-3"}


def test_scale_is_idempotent():
    docker_client = FakeDocker()
    actions = make_actions(docker_client=docker_client)
    actions.scale(FULL_TARGET)

    detail = actions.scale(FULL_TARGET)

    assert detail["instances_before"] == 3 and detail["added"] == []


def test_scale_starts_a_stopped_replica_instead_of_creating_one():
    docker_client = FakeDocker()
    add_replicas(docker_client, 1)
    docker_client.by_name["dc-sample-app-2"].status = "exited"

    detail = make_actions(docker_client=docker_client).scale(FULL_TARGET)

    assert sorted(detail["added"]) == ["dc-sample-app-2", "dc-sample-app-3"]
    assert [e for e in docker_client.log if e[0] == "create"] == [("create", "dc-sample-app-3", "dc-sample-app:dev")]


def test_scale_removes_its_replicas_when_one_is_unhealthy():
    docker_client = FakeDocker()

    def handler(request):
        return httpx.Response(200 if request.url.host == "dc-sample-app-2" else 503)

    actions = make_actions(docker_client=docker_client, transport=httpx.MockTransport(handler), health_timeout_seconds=0)
    with pytest.raises(ActionError, match="replicas added by this run were removed"):
        actions.scale(FULL_TARGET)

    assert set(docker_client.by_name) == {"dc-sample-app"}


def test_scale_is_refused_without_max_replicas():
    with pytest.raises(ActionError, match="not configured"):
        make_actions().scale(TARGET)
