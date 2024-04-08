#!/usr/bin/env bash

export IMAGE="quay.ceph.io/ceph-ci/ceph:main"
export CADM="https://raw.githubusercontent.com/ceph/ceph/main/src/cephadm/cephadm.py"

#systemctl start firewalld
export PATH=/root/bin:$PATH
mkdir -p /root/bin
{% if ceph_dev_folder is defined %}
  ln -s  /mnt{{ ceph_dev_folder }}/src/cephadm/cephadm  /root/bin/cephadm
{% else %}
  cd /root/bin
  curl -o cephadm --silent --remote-name --location  $CADM
{% endif %}
chmod +x /root/bin/cephadm
mkdir -p /etc/ceph
mon_ip=$(ifconfig eth0  | grep 'inet ' | awk '{ print $2}')
{% if ceph_dev_folder is defined %}
  cephadm  --image $IMAGE bootstrap --mon-ip $mon_ip --initial-dashboard-password {{ admin_password }} --skip-monitoring-stack --allow-fqdn-hostname --dashboard-password-noupdate --shared_ceph_folder /mnt/{{ ceph_dev_folder }}
{% else %}
  cephadm  --image $IMAGE bootstrap --mon-ip $mon_ip --initial-dashboard-password {{ admin_password }} --allow-fqdn-hostname --dashboard-password-noupdate
{% endif %}
fsid=$(cat /etc/ceph/ceph.conf | grep fsid | awk '{ print $3}')
{% for number in range(1, nodes) %}
  ssh-copy-id -f -i /etc/ceph/ceph.pub  -o StrictHostKeyChecking=no root@{{ node_prefix_1 }}-node-{{ '%d' % number }}
  cephadm shell --fsid $fsid -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.client.admin.keyring ceph orch host add {{ node_prefix_1 }}-node-{{ '%d' % number }} {{  ip_prefix_1 }}.10{{ '%d' % number }}
{% endfor %}
cephadm shell --fsid $fsid -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.client.admin.keyring ceph orch apply osd --all-available-devices
