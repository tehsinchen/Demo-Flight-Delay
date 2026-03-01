# Use a lightweight Python base image
FROM python:3.13-slim

# Prevent Python from writing .pyc files and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Taipei

# Set work directory
WORKDIR /app

# Install system dependencies (kept minimal)
RUN apt-get update \
    && apt-get install -y --no-install-recommends cron util-linux tzdata ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install Python dependencies first (better layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .
COPY db_config.py .
COPY airports_config.yaml .

# # Register cron job (every 30 minutes)
# RUN printf '%s\n' \
#   'SHELL=/bin/sh' \
#   'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
#   'CRON_TZ=Asia/Taipei' \
#   '@reboot . /etc/environment; cd /app && flock -n /var/run/crawler.lock /usr/local/bin/python main.py >> /var/log/cron.log 2>&1' \
#   '*/30 * * * * . /etc/environment; cd /app && flock -n /var/run/crawler.lock /usr/local/bin/python main.py >> /var/log/cron.log 2>&1' \
#   > /etc/cron.d/scheduler \
#  && chmod 0644 /etc/cron.d/scheduler \
#  && crontab /etc/cron.d/scheduler


# # Start cron in the foreground and stream job logs to container logs.
# # Also, snapshot the current container environment into /etc/environment so cron jobs can import it.
# CMD sh -c '\
#   printenv | sed -E "s/^([^=]+)=(.*)$/\1=\"\2\"/" > /etc/environment; \
#   touch /var/log/cron.log; \
#   tail -F /var/log/cron.log & \
#   exec cron -f \
# '
CMD ["python", "main.py"]