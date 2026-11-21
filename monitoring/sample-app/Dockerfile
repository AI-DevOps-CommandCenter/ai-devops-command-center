FROM python:3.13.5-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=8000

# Release identity. scripts/release.sh builds a "bad release" with
# APP_VERSION=v2 RELEASE_FAULT=errors:0.5 to demonstrate the rollback playbook.
ARG APP_VERSION=v1
ARG RELEASE_FAULT=
ENV APP_VERSION=${APP_VERSION}     RELEASE_FAULT=${RELEASE_FAULT}

WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ app/
COPY loadgen/ loadgen/

RUN useradd --system --uid 10001 appuser
USER appuser

EXPOSE 8000
# The load generator uses the same image: command `python -m loadgen.loadgen`.
CMD ["python", "-m", "app"]
