#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/mrinaldi/ProxmoxVE/refs/heads/ente-auth/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: mrinaldi
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: [SOURCE_URL]

APP="ente-auth"
var_tags="${var_tags:-2fa;authenticator}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-16}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d "/opt/ente-auth" ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  setup_postgresql
  LATEST=$(curl -fsSL https://api.github.com/repos/ente-io/ente/releases | jq '.[] | select(.prerelease == false and (.tag_name | startswith("auth-v")))' | jq -r '.tag_name' | head -n1)
  if check_for_gh_release "ente-auth" "ente-io/ente" $LATEST; then
    $STD apt update
    $STD apt -y upgrade

    msg_info "Creating Backup"
    mv "/opt/ente-auth" "/opt/ente-auth-backup"
    msg_ok "Backup Created"

    fetch_and_deploy_gh_release "ente-auth" "ente-io/ente" "tarball" $LATEST
    cp "/opt/ente-auth-backup/museum.yaml" "/opt/ente-auth/museum.yaml"
    $STD systemctl restart ente-auth
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
