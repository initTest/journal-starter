#!/usr/bin/env bash
set -eux

# ---------------- CONFIGURE THESE BEFORE LAUNCH ----------------
GIT_REPO="https://github.com/initTest/journal-starter.git"      # e.g. https://github.com/you/journal-starter.git
GIT_BRANCH="main"
APP_USER="ec2-user"
APP_DIR="/home/${APP_USER}/journal-starter"
APP_PORT=8000

# RDS connection values
RDSHOST="career-journal.cg7444qcmpyw.us-east-1.rds.amazonaws.com"
DB_NAME="career_journal"
DB_USER="postgres"
DB_PASS="postgres"

# Optional: public URL to an RDS CA bundle (if you want the instance to download it)
CERT_URL=""                               # e.g. https://s3.amazonaws.com/path/to/global-bundle.pem
CERT_PATH="/certs/global-bundle.pem"

# ----------------------------------------------------------------

# package manager (dnf for Amazon Linux 2023, yum otherwise)
if command -v dnf >/dev/null 2>&1; then
  PM="dnf"
else
  PM="yum"
fi

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

# install base packages
$PM -y install --allowerasing git nginx wget curl gcc openssl-devel bzip2-devel zlib-devel libffi-devel \
  postgresql-devel make ca-certificates python3.11 python3.11-devel || true


# ensure app dir and ownership
mkdir -p "$APP_DIR"
chown -R "$APP_USER:$APP_USER" "$(dirname "$APP_DIR")" || true

# clone app repo as app user
if [ ! -d "$APP_DIR/.git" ]; then
  sudo -u "$APP_USER" git clone --depth 1 --branch "$GIT_BRANCH" "$GIT_REPO" "$APP_DIR"
else
  cd "$APP_DIR"
  sudo -u "$APP_USER" git fetch --all --prune
  sudo -u "$APP_USER" git checkout "$GIT_BRANCH"
  sudo -u "$APP_USER" git pull
fi

cd "$APP_DIR"

# write .env with DATABASE_URL using SSL params (RDS)
DATABASE_URL="postgresql://${DB_USER}:${DB_PASS}@${RDSHOST}:5432/${DB_NAME}"
cat > .env <<EOF
# created by EC2 user-data
DATABASE_URL=${DATABASE_URL}
EOF
chown "$APP_USER:$APP_USER" .env
chmod 600 .env

# create virtual environment and install Python deps
sudo -u "$APP_USER" python3.11 -m venv "$APP_DIR/.venv"
sudo -u "$APP_USER" "$APP_DIR/.venv/bin/pip" install --upgrade pip wheel

# install runtime dependencies (matching pyproject.toml)
sudo -u "$APP_USER" "$APP_DIR/.venv/bin/pip" install \
  fastapi uvicorn[standard] python-dotenv aiohttp sqlalchemy \
  psycopg2-binary asyncpg

# create systemd service for running the app via uvicorn
SERVICE_NAME=journal-api
cat > /etc/systemd/system/${SERVICE_NAME}.service <<SERVICE
[Unit]
Description=Journal API (uvicorn)
After=network.target

[Service]
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
Environment="PATH=${APP_DIR}/.venv/bin"
EnvironmentFile=-${APP_DIR}/.env
ExecStart=${APP_DIR}/.venv/bin/uvicorn api.main:app --host 0.0.0.0 --port ${APP_PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now ${SERVICE_NAME}.service

# configure nginx as reverse proxy from :80 -> app port
cat > /etc/nginx/conf.d/journal.conf <<NGINX
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
NGINX

systemctl enable --now nginx

# ensure ownership
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

# quick health check (give service a few seconds)
sleep 5
if curl -sS "http://127.0.0.1:${APP_PORT}/docs" >/dev/null 2>&1; then
  echo "App is reachable locally"
else
  echo "App not reachable yet; show journal-api logs"
  journalctl -u ${SERVICE_NAME} --no-pager | tail -n 50 || true
fi

echo "User-data finished"
[root@ip-10-0-1-221 ec2-user]# 