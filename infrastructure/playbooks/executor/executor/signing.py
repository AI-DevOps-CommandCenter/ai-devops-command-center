"""HMAC-signed requests, same scheme as backend/src/middleware/machine-auth.ts
and automation/src/lib/hmac.js:

    canonical = timestamp + "." + nonce + "." + METHOD + "." + path + "." + rawBody
    X-DC-Signature = "sha256=" + hex(HMAC-SHA256(secret, canonical))

Requests more than 300 s from this clock are rejected and each nonce is
accepted once. The executor is a single process, so the in-memory nonce store
under a lock is atomic (unlike n8n static data, known issue KI-1).
"""

import hashlib
import hmac
import re
import threading
import time
from dataclasses import dataclass

MAX_CLOCK_SKEW_SECONDS = 300
MIN_SECRET_LENGTH = 32
NONCE_TTL_SECONDS = 15 * 60  # 3x the clock window, as in automation/src/lib/hmac.js
NONCE_PATTERN = re.compile(r"^[A-Za-z0-9_-]{16,200}$")
SIGNATURE_PATTERN = re.compile(r"^sha256=[0-9a-f]{64}$")
TIMESTAMP_PATTERN = re.compile(r"^\d{1,12}$")


def compute_signature(secret: str, timestamp: int, nonce: str, method: str, path: str, body: str) -> str:
    canonical = ".".join([str(timestamp), nonce, method.upper(), path, body])
    return "sha256=" + hmac.new(secret.encode(), canonical.encode(), hashlib.sha256).hexdigest()


def secret_is_valid(secret: str | None) -> bool:
    return isinstance(secret, str) and len(secret) >= MIN_SECRET_LENGTH


class NonceStore:
    """Remembers accepted nonces for NONCE_TTL_SECONDS."""

    def __init__(self):
        self._seen: dict[str, float] = {}
        self._lock = threading.Lock()

    def consume(self, nonce: str, now: float) -> bool:
        """Return True the first time a nonce is seen, False for a replay."""
        with self._lock:
            cutoff = now - NONCE_TTL_SECONDS
            for old in [n for n, at in self._seen.items() if at < cutoff]:
                del self._seen[old]
            if nonce in self._seen:
                return False
            self._seen[nonce] = now
            return True


@dataclass
class Verdict:
    ok: bool
    status: int
    reason: str | None = None


def verify(secret: str, headers, method: str, path: str, body: str, nonces: NonceStore, now: float | None = None) -> Verdict:
    now = time.time() if now is None else now
    timestamp = headers.get("x-dc-timestamp")
    nonce = headers.get("x-dc-nonce")
    signature = headers.get("x-dc-signature")

    if not timestamp or not nonce or not signature:
        return Verdict(False, 401, "Signed request headers are required.")
    if not TIMESTAMP_PATTERN.match(timestamp):
        return Verdict(False, 401, "Invalid request timestamp.")
    if abs(now - int(timestamp)) > MAX_CLOCK_SKEW_SECONDS:
        return Verdict(False, 401, "Signed request is outside the 5 minute window.")
    if not NONCE_PATTERN.match(nonce) or not SIGNATURE_PATTERN.match(signature):
        return Verdict(False, 401, "Invalid request signature.")

    expected = compute_signature(secret, int(timestamp), nonce, method, path, body)
    if not hmac.compare_digest(expected, signature):
        return Verdict(False, 401, "Invalid request signature.")
    if not nonces.consume(nonce, now):
        return Verdict(False, 409, "Replayed request.")
    return Verdict(True, 200)
