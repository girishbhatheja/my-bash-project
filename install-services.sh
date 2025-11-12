#!/bin/bash
#
# ===================================================
#  Systemd Service Installer
# ===================================================
#
# This script installs all the custom systemd services
# for my-bash-project.
#
# It must be run with sudo or as root.
#

# Stop immediately if any command fails
set -euo pipefail

echo "--- Starting systemd service installation..."

# --- 1. Simple Custom Service ---
echo "Creating simple-app.service..."
tee /etc/systemd/system/simple-app.service > /dev/null << EOF
[Unit]
Description=A simple custom application

[Service]
Type=simple
User=nobody
ExecStart=/bin/bash -c "while true; do echo \"Simple app is running - \$(date)\" >> /tmp/simple-app.log; sleep 60; done"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# --- 2. WebApp Service (with Env Vars) ---
echo "Creating webapp.service..."
tee /etc/systemd/system/webapp.service > /dev/null << EOF
[Unit]
Description=Web Application Service
After=network-online.target

[Service]
Type=oneshot
User=www-data
Group=www-data
Environment=APP_ENV=production
Environment=LOG_LEVEL=info
# This next line tells it to load the optional file
EnvironmentFile=-/etc/default/webapp
ExecStart=/bin/bash -c "echo \"Starting webapp with ENV=\$APP_ENV LEVEL=\$LOG_LEVEL DB=\$DATABASE_URL\" >> /tmp/webapp.log"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# --- 3. Environment File for WebApp ---
echo "Creating /etc/default/webapp environment file..."
mkdir -p /etc/default
tee /etc/default/webapp > /dev/null << EOF
DATABASE_URL=postgresql://localhost:5432/webapp
SECRET_KEY=mysecretkey123
EOF

# --- 4. Backup Service (The "Work") ---
echo "Creating backup.service..."
tee /etc/systemd/system/backup.service > /dev/null << EOF
[Unit]
Description=Run a simple backup

[Service]
Type=oneshot
User=root
ExecStart=/bin/bash -c "tar -czf /tmp/backup-\$(date +%%Y%%m%%d-%%H%%M%%S).tar.gz /etc/hosts /etc/hostname"
EOF

# --- 5. Backup Timer (The "Schedule") ---
echo "Creating backup.timer..."
tee /etc/systemd/system/backup.timer > /dev/null << EOF
[Unit]
Description=Run backup service daily at 2 AM
Requires=backup.service

[Timer]
OnCalendar=daily
AccuracySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

# --- 6. Secure App Service (Sandboxed) ---
echo "Creating secure-app.service..."
tee /etc/systemd/system/secure-app.service > /dev/null << EOF
[Unit]
Description=Secure Application
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=/bin/bash -c "while true; do echo \"Secure app running - \$(date)\" >> /tmp/secure-app.log; sleep 60; done"
Restart=always

# --- Security Settings ---
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp

[Install]
WantedBy=multi-user.target
EOF

# --- Final Step: Reload systemd ---
echo "--- Reloading systemd daemon..."
systemctl daemon-reload

echo "=========================================="
echo "✅ All services created successfully."
echo "You can now start/enable them, e.g.:"
echo "  sudo systemctl start simple-app.service"
echo "  sudo systemctl enable --now backup.timer"
echo "=========================================="
