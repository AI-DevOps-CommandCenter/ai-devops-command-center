"""JSON log lines on stdout, one object per line, for Promtail and Loki."""

import json
import logging
import sys
from datetime import datetime, timezone

# Extra fields copied into the JSON line when a log call passes them.
EXTRA_FIELDS = ("method", "route", "status", "duration_ms", "mode", "rate", "open")
# uvicorn logs its normal startup lines under "uvicorn.error"; the word "error"
# would make them match the error filter of n8n workflow 02.
LOGGER_ALIASES = {"uvicorn.error": "uvicorn"}


class JsonFormatter(logging.Formatter):
    def __init__(self, service: str):
        super().__init__()
        self.service = service

    def format(self, record: logging.LogRecord) -> str:
        entry = {
            "ts": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(timespec="milliseconds"),
            "level": record.levelname.lower(),
            "service": self.service,
            "logger": LOGGER_ALIASES.get(record.name, record.name),
            "msg": record.getMessage(),
        }
        for field in EXTRA_FIELDS:
            if hasattr(record, field):
                entry[field] = getattr(record, field)
        if record.exc_info:
            entry["exc"] = self.formatException(record.exc_info)
        return json.dumps(entry)


def setup_logging(service: str, level: str = "INFO") -> None:
    """Send every logger, uvicorn's included, through one JSON handler on stdout."""
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter(service))
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)
