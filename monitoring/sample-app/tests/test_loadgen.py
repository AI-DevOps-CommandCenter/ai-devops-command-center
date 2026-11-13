import threading

import httpx
import pytest

from loadgen.loadgen import env_float, run, send_one


def client_with(handler) -> httpx.Client:
    return httpx.Client(base_url="http://sample-app", transport=httpx.MockTransport(handler))


def test_run_counts_outcomes_by_status():
    statuses = iter([200, 500, 200, 404])
    client = client_with(lambda request: httpx.Response(next(statuses)))

    outcomes = run(client, rps=1000, report_every=60, stop=threading.Event(), max_requests=4)

    assert outcomes == {"200": 2, "500": 1, "404": 1}


def test_run_stops_when_stop_is_set():
    stop = threading.Event()
    stop.set()
    client = client_with(lambda request: httpx.Response(200))

    assert run(client, rps=1000, report_every=60, stop=stop) == {}


@pytest.mark.parametrize(
    "error, outcome",
    [(httpx.ReadTimeout("slow"), "timeout"), (httpx.ConnectError("refused"), "connect_error")],
)
def test_failed_request_is_counted_not_retried(error, outcome):
    calls = []

    def handler(request):
        calls.append(request)
        raise error

    assert send_one(client_with(handler), "/api/orders") == outcome
    assert len(calls) == 1


def test_env_float_rejects_out_of_range(monkeypatch):
    monkeypatch.setenv("LOADGEN_RPS", "500")
    with pytest.raises(ValueError):
        env_float("LOADGEN_RPS", 5, 0.1, 50)
