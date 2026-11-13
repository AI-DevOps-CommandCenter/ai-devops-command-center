FROM python:3.13.5-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=9095 \
    EXECUTOR_ALLOWLIST=/srv/allowlist.json

WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY executor/ executor/
COPY allowlist.json .

# Non-root. Docker socket access comes from the socket's group (group_add in compose).
RUN useradd --system --uid 10001 executor
USER executor

EXPOSE 9095
CMD ["python", "-m", "executor"]
