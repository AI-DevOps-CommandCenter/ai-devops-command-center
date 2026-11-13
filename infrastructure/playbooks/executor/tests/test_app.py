import time

import pytest
from fastapi.testclient import TestClient

from executor.app import EXECUTE_PATH
from tests.helpers import FakeDocker, make_actions, make_app, request_body, sample_app_transport, signed


def post(client, body, **sign_options):
    raw, headers = signed(body, **sign_options)
    return client.post(EXECUTE_PATH, content=raw, headers=headers)


@pytest.fixture
def docker_client():
    return FakeDocker()


@pytest.fixture
def client(docker_client):
    return TestClient(make_app(make_actions(docker_client=docker_client)))


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_restart_runs_once_and_reports_result(client, docker_client):
    response = post(client, request_body())

    assert response.status_code == 200
    body = response.json()
    assert body["executed"] is True and body["repeated"] is False
    assert body["action"] == "restart" and body["service_name"] == "sample-app"
    assert body["detail"]["container"] == "dc-sample-app"
    assert docker_client.by_name["dc-sample-app"].restarts == [10]


def test_repeat_of_same_run_returns_stored_result_without_running_again(client, docker_client):
    first = post(client, request_body())
    second = post(client, request_body())  # new nonce and timestamp, same run

    assert second.status_code == 200
    assert second.json()["repeated"] is True
    assert second.json()["started_at"] == first.json()["started_at"]
    assert len(docker_client.by_name["dc-sample-app"].restarts) == 1


def test_same_run_id_for_a_different_action_is_refused(client):
    post(client, request_body(action="restart"))
    assert post(client, request_body(action="circuit_breaker")).status_code == 409


def test_replayed_request_is_refused(client, docker_client):
    raw, headers = signed(request_body())
    assert client.post(EXECUTE_PATH, content=raw, headers=headers).status_code == 200

    replay = client.post(EXECUTE_PATH, content=raw, headers=headers)

    assert replay.status_code == 409
    assert replay.json()["message"] == "Replayed request."
    assert len(docker_client.by_name["dc-sample-app"].restarts) == 1


@pytest.mark.parametrize(
    "sign_options",
    [
        {"secret": "wrong-secret-0123456789abcdef0123456789"},
        {"timestamp": int(time.time()) - 301},
        {"path": "/webhook/remediation"},  # a signature for another endpoint
        {"nonce": "short"},
    ],
)
def test_bad_signature_is_401_and_runs_nothing(client, docker_client, sign_options):
    assert post(client, request_body(), **sign_options).status_code == 401
    assert docker_client.by_name["dc-sample-app"].restarts == []


def test_missing_headers_is_401(client):
    assert client.post(EXECUTE_PATH, json=request_body()).status_code == 401


def test_body_changed_after_signing_is_401(client):
    raw, headers = signed(request_body())
    assert client.post(EXECUTE_PATH, content=raw.replace("sample-app", "sample-apq"), headers=headers).status_code == 401


@pytest.mark.parametrize(
    "body",
    [
        request_body(command="rm -rf /"),  # extra field
        request_body(run_id="not-a-uuid"),
        request_body(action="shell"),
        request_body(service_name='bad"name'),
        "not json",
    ],
)
def test_invalid_body_is_400(client, body):
    assert post(client, body).status_code == 400


def test_service_outside_allowlist_is_403(client):
    assert post(client, request_body(service_name="checkout-api")).status_code == 403


@pytest.mark.parametrize("action", ["rollback", "scale"])
def test_action_not_granted_for_service_is_422(client, action):
    assert post(client, request_body(action=action)).status_code == 422


def test_missing_secret_is_503():
    client = TestClient(make_app(secret=None))
    assert post(client, request_body()).status_code == 503


def test_failed_action_is_500_and_stored(docker_client):
    client = TestClient(make_app(make_actions(docker_client=FakeDocker(names=()))))

    first = post(client, request_body())
    repeat = post(client, request_body())

    assert first.status_code == 500
    assert first.json()["executed"] is False
    assert "not found" in first.json()["message"]
    assert repeat.status_code == 500 and repeat.json()["repeated"] is True


def test_circuit_breaker_opens(client):
    response = post(client, request_body(action="circuit_breaker"))

    assert response.status_code == 200
    assert response.json()["detail"] == {"breaker_open": True, "attempts": 1}


def test_circuit_breaker_gives_up_after_three_server_errors():
    transport, calls = sample_app_transport(breaker_statuses=[503, 503, 503])
    client = TestClient(make_app(make_actions(transport=transport)))

    response = post(client, request_body(action="circuit_breaker"))

    assert response.status_code == 500
    assert len(calls) == 3
