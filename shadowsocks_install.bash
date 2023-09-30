#!/usr/bin/env bash

cd $(mktemp -d /tmp/script.XXXXXXX) || exit
TEMP_DIR=$(pwd)

apt install -y jq
upstreamdata=$(curl -s "https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest")
shadowsocks_url=$(echo "$upstreamdata" | jq -r '.assets[]  | select(.name | contains("x86_64-unknown-linux-gnu")).browser_download_url' | grep -v sha256)

wget -c "$shadowsocks_url"
wget -c https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.1/v2ray-plugin-linux-amd64-v1.3.1.tar.gz
wget -c https://gist.github.com/Nill-R/b29b95f623d4da1a23175a0392c00eb6/raw/24836827cefc202a874591110bf380c66a6f0490/shadowsocks-rust.service

PASS=$(tr -cd '[:alnum:]' </dev/urandom | fold -w24 | head -n1)
# IP=$(ip -4 r s | grep default | awk {'printf $9'})
DEV=$(ip -4 r s | grep default | awk {'printf $5'})
IP=$(ip a s dev $DEV|grep inet|grep brd|awk {'printf $2'}|cut -d '/' -f1)
EXTERNAL_IP=$(wget -4 -qO- https://ip.lindon.pw)

printf "{\n\"server\":\"%s\",\n\"server_port\":8389,\n\"local_port\":3181,\n\"password\":\"$PASS\",\n\"timeout\":60,\n\"method\":\"aes-256-gcm\",\n\"plugin\":\"v2ray-plugin\",\n\"plugin_opts\": \"server\",\n\"fast_open\":true,\n\"reuse_port\":true,\n\"nameserver\": \"1.1.1.1\"\n}\n" "$IP" >config.json
mkdir -p /etc/shadowsocks-rust/

tar xzf v2ray-plugin-linux-amd64-v1.3.1.tar.gz
tar xJf shadowsocks*.tar.xz

mv ss* /usr/local/bin/
mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin
mv config.json /etc/shadowsocks-rust/
mv shadowsocks-rust.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now shadowsocks-rust

printf "Your external IP for connect to shadowsocks is %s\n" "$EXTERNAL_IP"
printf "Your config for shadowsocks:\n"
cat /etc/shadowsocks-rust/config.json

cd ~ || exit
rm -rf "$TEMP_DIR"

exit 0
