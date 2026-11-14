import httpx
import pytest

from executor.actions import ActionError
from tests.helpers import TARGET, make_actions, sample_app_transport


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

    assert make_actions(transport=transport).open_circuit_breaker(TARGET) == {"breaker_open": True, "attempts": 2}
    assert len(calls) == 2


def test_circuit_breaker_does_not_retry_client_errors():
    transport, calls = sample_app_transport(breaker_statuses=[422])

    with pytest.raises(ActionError, match="HTTP 422"):
        make_actions(transport=transport).open_circuit_breaker(TARGET)
    assert len(calls) == 1


def test_unimplemented_action_is_refused():
    with pytest.raises(ActionError, match="not implemented"):
        make_actions().run("rollback", TARGET)
