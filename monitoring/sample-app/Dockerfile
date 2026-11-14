FROM python:3.13.5-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=8000

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
