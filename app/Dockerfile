# Stage 1: Build dependencies
FROM python:3.12-alpine AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --no-compile --user -r requirements.txt


# Stage 2: Minimal production image
FROM python:3.12-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -S -g 1001 appgroup && \
    adduser  -S -u 1001 -G appgroup -h /home/appuser appuser

# Copy installed packages from builder stage
COPY --from=builder --chown=appuser:appgroup /root/.local /home/appuser/.local

# Copy application code
COPY --chown=appuser:appgroup app.py          .
COPY --chown=appuser:appgroup gunicorn.conf.py .

USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH \
    LOG_LEVEL=info \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 5000

# Graceful shutdown: gunicorn reads graceful_timeout from gunicorn.conf.py
# and finishes in-flight requests before exiting on SIGTERM
CMD ["gunicorn", "--config", "gunicorn.conf.py", "app:app"]
