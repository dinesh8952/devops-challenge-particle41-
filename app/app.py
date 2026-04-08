import json
import logging
import os
import signal
import time
import uuid
from datetime import datetime, timezone

from flask import Flask, g, jsonify, request

# ── Structured JSON logging ───────────────────────────────────────────────────

class JsonFormatter(logging.Formatter):
    def format(self, record):
        base = {
            "time":  datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
        }
        msg = record.getMessage()
        try:
            base.update(json.loads(msg))
        except (json.JSONDecodeError, TypeError):
            base["message"] = msg
        return json.dumps(base)


handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper(), handlers=[handler])
logger = logging.getLogger(__name__)

# ── App ───────────────────────────────────────────────────────────────────────

app = Flask(__name__)


# ── Graceful shutdown ─────────────────────────────────────────────────────────
# ECS sends SIGTERM before killing the container. We catch it so in-flight
# requests finish cleanly instead of being dropped mid-response.

_shutting_down = False

def _handle_sigterm(*_):
    global _shutting_down
    _shutting_down = True
    logger.info(json.dumps({"message": "SIGTERM received — draining connections"}))

signal.signal(signal.SIGTERM, _handle_sigterm)


# ── Request lifecycle hooks ───────────────────────────────────────────────────

@app.before_request
def before():
    g.start      = time.time()
    g.request_id = request.headers.get("X-Request-Id") or str(uuid.uuid4())


@app.after_request
def after(response):
    duration_ms = round((time.time() - g.start) * 1000, 2)
    logger.info(json.dumps({
        "request_id":  g.request_id,
        "method":      request.method,
        "path":        request.path,
        "status":      response.status_code,
        "duration_ms": duration_ms,
        "ip":          _client_ip(),
    }))
    # Propagate request ID to caller so they can correlate logs
    response.headers["X-Request-Id"] = g.request_id
    return response


# ── Helpers ───────────────────────────────────────────────────────────────────

def _client_ip() -> str:
    """Return the real client IP, handling ALB's X-Forwarded-For header."""
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.remote_addr or "unknown"


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return jsonify({
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "ip":        _client_ip(),
    })


@app.route("/health")
def health():
    """
    Health check used by both ALB and ECS container health check.
    Returns 503 during graceful shutdown so ALB stops sending new traffic
    before the container is killed.
    """
    if _shutting_down:
        return jsonify({"status": "shutting_down"}), 503
    return jsonify({"status": "healthy"}), 200


# ── Dev entrypoint ────────────────────────────────────────────────────────────
# Production uses gunicorn (see gunicorn.conf.py). This block is only for
# local development: `python app.py`

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
