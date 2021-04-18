#!/usr/bin/env bash

apt update
apt -y install gdebi-core
cd $(mktemp -d backup.XXXXXXX)
TEMP_DIR=`pwd`
wget http://www.tataranovich.com/debian/pool/sid/main/t/tataranovich-keyring/tataranovich-keyring_2020.06.12_all.deb
gdebi --n tataranovich-keyring_2020.06.12_all.deb
printf "deb http://www.tataranovich.com/ubuntu bionic main\n" >/etc/apt/sources.list.d/mc.list
rm -rf $TEMP_DIR
apt update
apt -y dist-upgrade
apt -y install git mc curl wget pydf ncdu vim bash-completion grc ssh-import-id tmux screen molly-guard htop
ssh-import-id gh:Nill-R
sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication no/g" /etc/ssh/sshd_config
systemctl restart ssh
cd $HOME
git clone https://github.com/Nill-R/bashrc.git; ./bashrc/enable_bashrc.bash; source $HOME/.bashrc
wget -c https://gist.github.com/Nill-R/ad2e95964c7b1ce50bcc5db52c0809a9/raw/9ad06bd17ebcbf7860f094ffa00226e009621451/.tmux.conf
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
