#!/bin/bash

now=`date +%Y%m%d%H%S`

sed -i".$now" \
 -e '/PermitRootLogin/s/.*//' \
 -e '/AllowUsers/s/.*//' \
 -e '/PasswordAuthentication/s/.*//' /etc/ssh/sshd_config

echo "
AllowUsers root alex
PermitRootLogin yes
PasswordAuthentication yes" >> /etc/ssh/sshd_config

chmod og-rwx /root -R

curl -s -L $$Cfg.http.external_url/rsapub >> /root/.ssh/authorized_keys
/etc/init.d/ssh restart
