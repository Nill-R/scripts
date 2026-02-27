#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# Define constants
UPSTREAM_URL="https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest"
PLUGIN_URL="https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.1/v2ray-plugin-linux-amd64-v1.3.1.tar.gz"
SERVICE_URL="https://gist.github.com/Nill-R/b29b95f623d4da1a23175a0392c00eb6/raw/24836827cefc202a874591110bf380c66a6f0490/shadowsocks-rust.service"
EXTERNAL_IP_URL="https://ip.lindon.pw"

# Function to install required packages
install_packages() {
    apt install -y jq || { echo "Error installing jq"; exit 1; }
}

# Function to download files
download_files() {
    upstreamdata=$(curl -s "$UPSTREAM_URL")
    shadowsocks_url=$(echo "$upstreamdata" | jq -r '.assets[]  | select(.name | contains("x86_64-unknown-linux-gnu")).browser_download_url' | grep -v sha256)

    wget -c "$shadowsocks_url" || { echo "Error downloading Shadowsocks"; exit 1; }
    wget -c "$PLUGIN_URL" || { echo "Error downloading V2Ray plugin"; exit 1; }
    wget -c "$SERVICE_URL" || { echo "Error downloading systemd service"; exit 1; }
}

# Function to configure
configure() {
    PASS=$(tr -cd '[:alnum:]' </dev/urandom | fold -w24 | head -n1)
    DEV=$(ip -4 r s | grep default | awk {'printf $5'})
    IP=$(ip a s dev "$DEV" | grep inet | grep brd | awk {'printf $2'} | cut -d '/' -f1)
    EXTERNAL_IP=$(wget -4 -qO- "$EXTERNAL_IP_URL")

    # Create config file using jq
    config_json=$(jq -n \
        --arg ip "$IP" \
        --arg pass "$PASS" \
        --arg ext_ip "$EXTERNAL_IP" \
        '{server: $ip, server_port: 8389, local_port: 3181, password: $pass, timeout: 60, method: "aes-256-gcm", plugin: "v2ray-plugin", plugin_opts: "server", fast_open: true, reuse_port: true, nameserver: "1.1.1.1"}')

    echo "$config_json" > /etc/shadowsocks-rust/config.json
}

# Function to install and start service
setup_service() {
    mkdir -p /etc/shadowsocks-rust/

    tar xzf v2ray-plugin-linux-amd64-v1.3.1.tar.gz
    tar xJf shadowsocks*.tar.xz

    mv ss* /usr/local/bin/
    mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin
    mv shadowsocks-rust.service /etc/systemd/system/

    systemctl daemon-reload
    systemctl enable --now shadowsocks-rust
}

# Function to print info
print_info() {
    printf "Your external IP for connect to shadowsocks is %s\n" "$EXTERNAL_IP"
    printf "Your config for shadowsocks:\n"
    cat /etc/shadowsocks-rust/config.json
}

# Main execution sequence
main() {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/script.XXXXXXX) || { echo "Error creating temporary directory"; exit 1; }
    cd "$temp_dir" || { echo "Error entering temporary directory"; exit 1; }

    install_packages
    download_files
    configure
    setup_service
    print_info

    cd ~ || { echo "Error exiting temporary directory"; exit 1; }
    rm -rf "$temp_dir"
}

main "$@"