import json
from pathlib import Path

import pytest

from executor.allowlist import load_allowlist
from executor.signing import NONCE_TTL_SECONDS, NonceStore, compute_signature


def test_signature_matches_vector_from_project_js_implementation():
    # Produced by hmacSignature() in automation/src/lib/hmac.js
    # (branch feature/n8n-incident-workflow) with these exact inputs.
    body = '{"action":"restart","service_name":"sample-app","playbook_run_id":"11111111-1111-4111-8111-111111111111"}'
    signature = compute_signature("interop-vector-secret-0123456789abcdef", 1794540000, "vectorNonce_0123456789", "post", "/v1/execute", body)
    assert signature == JS_VECTOR_SIGNATURE


def test_nonce_is_accepted_once_until_it_expires():
    store = NonceStore()
    assert store.consume("abc", now=1000) is True
    assert store.consume("abc", now=1001) is False
    assert store.consume("abc", now=1000 + NONCE_TTL_SECONDS + 1) is True


def test_repository_allowlist_loads():
    targets = load_allowlist(Path(__file__).resolve().parent.parent / "allowlist.json")
    assert set(targets["sample-app"].actions) == {"restart", "circuit_breaker"}


def test_allowlist_rejects_unknown_action(tmp_path):
    path = tmp_path / "allowlist.json"
    path.write_text(json.dumps({"x": {"container": "c", "base_url": "http://x", "actions": ["shell"]}}))
    with pytest.raises(ValueError, match="Unknown actions"):
        load_allowlist(path)


JS_VECTOR_SIGNATURE = "sha256=6123fcc6ec32fea7580b6a10f550a9f39f42acc8a1ba205e877b4c98ae7332ad"
