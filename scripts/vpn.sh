#!/bin/bash
BOXID=$$report_id
sed -i -re 's/([a-z]{2}\.)?archive.ubuntu.com|security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list
apt-get update
apt-get install --assume-yes  openvpn
#fw
apt-get install --assume-yes iptables-persistent
iptables -A OUTPUT -p udp --dport $$Cfg.vpn.port -j ACCEPT
iptables -A INPUT -s 10.10.0.0/255.255.0.0 -p tcp --dport 22 -j ACCEPT
iptables-save > /etc/iptables/rules
#ssh
cat /dev/zero | ssh-keygen -N '' -q 
cat /dev/zero | ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' -q
cat /dev/zero | ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N '' -q
curl -s -L $$Cfg.http.external_url/rsa_pub >> /root/.ssh/authorized_keys
/etc/init.d/ssh restart
#vpn
cp /etc/openvpn/client.conf /etc/openvpn/client.conf.$(date +%F_%R) 2>/dev/null || :
curl -s -L $$Cfg.http.external_url/vpn/$BOXID > /etc/openvpn/client.conf
# echo '<cert>' >> /etc/openvpn/client.conf
# curl -s -L $$Cfg.http.external_url/vc/$$report_id >> /etc/openvpn/client.conf
# echo '</cert>' >> /etc/openvpn/client.conf
# echo '<key>' >> /etc/openvpn/client.conf
# curl -s -L $$Cfg.http.external_url/vk/$$report_id >> /etc/openvpn/client.conf
# echo '</key>' >> /etc/openvpn/client.conf

sed -i '/AUTOSTART="all"/d' /etc/default/openvpn
echo 'AUTOSTART="all"' >> /etc/default/openvpn
sed -i '/AllowUsers root/d' /etc/ssh/sshd_config
echo 'AllowUsers root' >> /etc/ssh/sshd_config
/etc/init.d/openvpn restart
