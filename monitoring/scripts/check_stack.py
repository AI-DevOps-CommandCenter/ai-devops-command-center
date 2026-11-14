"""Check the running monitoring stack from the host and print PASS/FAIL per check.

Runs every PROM_QUERY_* from n8n-integration.env against the live Prometheus,
so the values handed to the n8n workflows are the ones tested here.
Standard library only. Each HTTP call has a timeout and is not retried.

    python scripts/check_stack.py [--service sample-app]
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

TIMEOUT_SECONDS = 10
ENV_FILE = Path(__file__).resolve().parent.parent / "n8n-integration.env"
# The workflow 02 filter (automation/src/nodes/02-log-analysis/build-query.js).
LOG_FILTER = '|~ "(?i)(error|exception|fatal|panic|critical|warn)"'

results: list[bool] = []


def report(name: str, ok: bool, detail: str = "") -> None:
    results.append(ok)
    print(f"  {'PASS' if ok else 'FAIL'} {name}" + (f"  {detail}" if detail else ""))


def get(url: str) -> tuple[int, str]:
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()
    except (urllib.error.URLError, TimeoutError) as error:
        return 0, str(error)


def get_json(url: str) -> dict:
    status, body = get(url)
    if status != 200:
        return {"_error": f"HTTP {status}: {body[:200]}"}
    return json.loads(body)


def read_env(path: Path) -> dict[str, str]:
    values = {}
    for line in path.read_text().splitlines():
        if line.strip() and not line.lstrip().startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def prom_query(prom: str, query: str) -> list:
    data = get_json(f"{prom}/api/v1/query?" + urllib.parse.urlencode({"query": query}))
    if data.get("status") != "success":
        raise ValueError(data.get("_error") or data.get("error"))
    return data["data"]["result"]


def check_prometheus(prom: str, service: str, env: dict[str, str]) -> None:
    print("Prometheus")
    status, _ = get(f"{prom}/-/ready")
    report("ready", status == 200, f"HTTP {status}")

    targets = get_json(f"{prom}/api/v1/targets").get("data", {}).get("activeTargets", [])
    for target in targets:
        report(f"target {target['labels'].get('service')} up", target["health"] == "up", target.get("lastError", ""))

    rules = json.dumps(get_json(f"{prom}/api/v1/rules"))
    for alert in ("HighErrorRate", "ServiceDown"):
        report(f"rule {alert} loaded", f'"name": "{alert}"' in rules)

    queries = {key: value for key, value in env.items() if key.startswith("PROM_QUERY_") and value}
    queries["up (workflow 07)"] = f'min(up{{{env["PROM_SERVICE_LABEL"]}="{{{{service}}}}"}})'
    queries["cpu default (workflow 03)"] = f'sum(rate(process_cpu_seconds_total{{{env["PROM_SERVICE_LABEL"]}="{{{{service}}}}"}}[5m]))'
    queries["memory default (workflow 03)"] = f'sum(process_resident_memory_bytes{{{env["PROM_SERVICE_LABEL"]}="{{{{service}}}}"}})'
    for name, template in queries.items():
        query = template.replace("{{service}}", service)
        try:
            result = prom_query(prom, query)
            values = [r["value"][1] for r in result]
            report(f"query {name} returns a number", len(values) == 1 and values[0] not in ("NaN", "+Inf"), f"value={values}")
        except ValueError as error:
            report(f"query {name} returns a number", False, str(error))


def check_alertmanager(am: str) -> None:
    print("Alertmanager")
    status, _ = get(f"{am}/-/ready")
    report("ready", status == 200, f"HTTP {status}")
    status, _ = get(f"{am}/api/v2/status")
    report("API answers", status == 200, f"HTTP {status}")


def check_loki(loki: str, service: str, env: dict[str, str]) -> None:
    print("Loki")
    status, _ = get(f"{loki}/ready")
    report("ready", status == 200, f"HTTP {status}")

    label = env["LOKI_SERVICE_LABEL"]
    values = get_json(f"{loki}/loki/api/v1/label/{label}/values").get("data", [])
    report(f"label {label} has {service}", service in values, f"values={values}")

    end = time.time_ns()
    params = {"query": f'{{{label}="{service}"}}', "start": end - 5 * 60 * 10**9, "end": end, "limit": 5}
    streams = get_json(f"{loki}/loki/api/v1/query_range?" + urllib.parse.urlencode(params)).get("data", {}).get("result", [])
    report("log lines in the last 5 minutes", any(s["values"] for s in streams))

    params["query"] = f'{{{label}="{service}"}} {LOG_FILTER}'
    streams = get_json(f"{loki}/loki/api/v1/query_range?" + urllib.parse.urlencode(params)).get("data", {}).get("result", [])
    count = sum(len(s["values"]) for s in streams)
    print(f"  INFO workflow 02 query matched {count} line(s) in the last 5 minutes (0 is normal without a fault)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--service", default="sample-app")
    parser.add_argument("--prometheus", default="http://127.0.0.1:9090")
    parser.add_argument("--alertmanager", default="http://127.0.0.1:9093")
    parser.add_argument("--loki", default="http://127.0.0.1:3100")
    args = parser.parse_args()

    env = read_env(ENV_FILE)
    check_prometheus(args.prometheus, args.service, env)
    check_alertmanager(args.alertmanager)
    check_loki(args.loki, args.service, env)

    failed = results.count(False)
    print(f"\n{len(results) - failed} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
