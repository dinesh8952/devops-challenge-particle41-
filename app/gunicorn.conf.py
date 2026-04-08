import multiprocessing
import os

# Server socket
bind = "0.0.0.0:5000"

# Workers — 2 sync workers is right for 0.25 vCPU Fargate tasks
# Formula: (2 * cpu_count) + 1, but cap at 2 for low-CPU containers
workers = int(os.environ.get("GUNICORN_WORKERS", 2))
worker_class = "sync"
threads = 1

# Timeouts
timeout = 30          # Kill worker if request takes > 30s (also recycles idle keep-alive faster)
graceful_timeout = 25 # Wait 25s for workers to finish on SIGTERM before SIGKILL
keepalive = 2         # Close idle keep-alive connections after 2s

# Logging — Flask's after_request hook handles structured access logging
# (includes request_id, real IP, ms precision). Gunicorn access log disabled
# to avoid duplicate lines in CloudWatch.
accesslog = None
errorlog = "-"
loglevel = os.environ.get("LOG_LEVEL", "info")

# Process naming
proc_name = "simpletimeservice"

# Security — prevent gunicorn from exposing version
server_header = False
sendfile = False
