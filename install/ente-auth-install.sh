#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: mrinaldi
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/ente-io/ente

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt install -y \
    libsodium23 \
    libsodium-dev \
    pkg-config \
    npm \
    nodejs \
    caddy
$STD npm install -g corepack
msg_ok "Installed Dependencies"

setup_go
setup_postgresql

LATEST=$(curl -fsSL https://api.github.com/repos/ente-io/ente/releases | jq '.[] | select(.prerelease == false and (.tag_name | startswith("auth-v")))' | jq -r '.tag_name' | head -n1)

fetch_and_deploy_gh_release "ente-auth" "ente-io/ente" "tarball" "$LATEST"

msg_info "Building ente-auth"
cd /opt/ente-auth/server || exit
$STD go mod tidy
$STD go build cmd/museum/main.go
cd /opt/ente-auth/web || exit
$STD yarn install -y
$STD yarn build:auth
mkdir -p /opt/ente-auth/www/auth
cp -r apps/auth/out /opt/ente-auth/www/auth
msg_ok "Building ente-auth"

msg_info "Configure ente-auth"
read -rp "${TAB3}Enter your email address: " admin_email
APP_KEY=$(openssl rand -base64 32)
KEY_HASH=$(openssl rand -base64 64)
JWT_SECRET="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | cut -c1-32)"
OTT="$(LC_ALL=C tr -dc '0-9' </dev/urandom | head -c 6)"

PG_DB_NAME="ente_db" PG_DB_USER="ente_user" setup_postgresql_db
cat <<EOF >/opt/ente-auth/server/museum.yaml
db:
    host: localhost
    port: 5432
    name: $PG_DB_NAME
    user: $PG_DB_USER
    password: $PG_DB_PASS

key:
    encryption: $APP_KEY
    hash: $KEY_HASH

jwt:
    secret: $JWT_SECRET

internal:
    hardcoded-ott:
        emails:
            - "$admin_email,$OTT"
EOF

cat <<EOF >/etc/caddy/Caddyfile
:3003 {
    root * /opt/ente-auth/www/auth
    file_server
    try_files {path} {path}.html /index.html
}
EOF
msg_ok "Configure ente-auth"

msg_info "Configure ente-auth service"
cat <<'EOF' >/etc/systemd/system/ente-auth.service
[Unit]
Description=Ente Auth is an open-source authenticator app that will let you backup and view your 2FA secrets

[Service]
Type=simple
WorkingDirectory=/opt/ente-auth/server
ExecStart=main
Restart=on-failure
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now caddy
systemctl enable --now ente-auth

msg_ok "Configure ente-auth service"

motd_ssh
customize
cleanup_lxc
