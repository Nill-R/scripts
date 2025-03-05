#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

apt update
apt -y install lsb-release

CODENAME=$(lsb_release -c -s)

# printf "deb mirror://mirrors.ubuntu.com/mirrors.txt $CODENAME main restricted\ndeb mirror://mirrors.ubuntu.com/mirrors.txt $CODENAME-updates main restricted\ndeb mirror://mirrors.ubuntu.com/mirrors.txt $CODENAME universe\ndeb mirror://mirrors.ubuntu.com/mirrors.txt $CODENAME-updates universe\ndeb mirror://mirrors.ubuntu.com/mirrors.txt $CODENAME multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt $CODENAME-updates multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt $CODENAME-backports main restricted universe multiverse\ndeb http://security.ubuntu.com/ubuntu $CODENAME-security main restricted\ndeb http://security.ubuntu.com/ubuntu $CODENAME-security universe\ndeb http://security.ubuntu.com/ubuntu $CODENAME-security multiverse\n###\n">/etc/apt/sources.list

cd $(mktemp -d backup.XXXXXXX)
TEMP_DIR=$(pwd)

apt update
apt -y install gdebi-core software-properties-common apt-transport-https curl

# add mc repo and repo key
curl -fsSL http://www.tataranovich.com/debian/gpg | sudo apt-key add -
printf "deb http://www.tataranovich.com/ubuntu $CODENAME main\n" >/etc/apt/sources.list.d/mc.list

# add MariaDB repo
wget https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
chmod +x mariadb_repo_setup
./mariadb_repo_setup

# add nginx ppa
apt-add-repository -y ppa:nill-rinov/nill-nginx-ppa
apt -y dist-upgrade

# install nginx and modules
apt -y install nginx-module-brotli nginx-module-cache-purge nginx-module-ct nginx-module-devel-kit nginx-module-fancyindex nginx-module-geoip nginx-module-geoip2 nginx-module-graphite nginx-module-http-auth-pam nginx-module-http-echo nginx-module-http-headers-more nginx-module-http-subs-filter nginx-module-image-filter nginx-module-lenght-hiding-filter nginx-module-lua nginx-module-mail nginx-module-naxsi nginx-module-nchan nginx-module-njs nginx-module-pagespeed nginx-module-perl nginx-module-rds-json nginx-module-rtmp nginx-module-session-binding-proxy nginx-module-stream nginx-module-stream-sts nginx-module-sts nginx-module-testcookie nginx-module-ts nginx-module-upload-progress nginx-module-upstream-fair nginx-module-upstream-order nginx-module-vts nginx-module-xslt

# install utilites
apt -y install git mc wget pydf ncdu vim bash-completion grc ssh-import-id tmux screen molly-guard htop python3-pip zstd zsh
pip3 install apprise telegram-send sch
ssh-import-id gh:Nill-R
sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication no/g" /etc/ssh/sshd_config
systemctl restart ssh

# downloads scripts
wget https://github.com/Nill-R/scripts/raw/main/mysql_backup.bash
wget https://github.com/Nill-R/scripts/raw/main/create_db_and_user.bash
wget https://github.com/Nill-R/scripts/raw/main/lego_cert.bash
chmod +x *.bash
mv ./*.bash /usr/local/bin/

cd "$HOME"
git clone https://github.com/Nill-R/bashrc.git
./bashrc/enable_bashrc.bash
source $HOME/.bashrc
printf ":set paste\n:set nu\n" >~/.vimrc

wget -c https://gist.github.com/Nill-R/ad2e95964c7b1ce50bcc5db52c0809a9/raw/ecb24ffe5bdf0156905ef9c6ea04b1592c0cb062/.tmux.conf
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

rm -rf "$TEMP_DIR"

exit 0
