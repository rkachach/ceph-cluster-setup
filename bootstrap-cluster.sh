#!/usr/bin/env bash
set -x
export IMAGE="quay.ceph.io/ceph-ci/ceph:main"

#systemctl start firewalld
export PATH=/root/bin:$PATH
mkdir -p /root/bin
{% if ceph_dev_folder is defined %}
  ln -s  /mnt{{ ceph_dev_folder }}/src/cephadm/cephadm  /root/bin/cephadm
{% else %}
  podman run --rm --entrypoint=cat quay.ceph.io/ceph-ci/ceph:main /usr/sbin/cephadm > /root/bin/cephadm
{% endif %}
chmod a+rx /root/bin/cephadm
mkdir -p /etc/ceph
mon_ip=$(ifconfig ens3  | grep 'inet ' | awk '{ print $2}')
{% if ceph_dev_folder is defined %}
  python3 /root/bin/cephadm  --image $IMAGE bootstrap --mon-ip $mon_ip --initial-dashboard-password {{ admin_password }} --skip-monitoring-stack --allow-fqdn-hostname --dashboard-password-noupdate --shared_ceph_folder /mnt/{{ ceph_dev_folder }} 
{% else %}
  python3 /root/bin/cephadm  --image $IMAGE bootstrap --mon-ip $mon_ip --initial-dashboard-password {{ admin_password }} --allow-fqdn-hostname --dashboard-password-noupdate
{% endif %}
fsid=$(cat /etc/ceph/ceph.conf | grep fsid | awk '{ print $3}')
{% for number in range(1, nodes) %}
  ssh-copy-id -f -i /etc/ceph/ceph.pub  -o StrictHostKeyChecking=no root@{{ node_prefix_1 }}-node-{{ '%d' % number }}
  python3 /root/bin/cephadm shell --fsid $fsid -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.client.admin.keyring ceph orch host add {{ node_prefix_1 }}-node-{{ '%d' % number }} {{  ip_prefix_1 }}.10{{ '%d' % number }}
{% endfor %}
python3 /root/bin/cephadm shell --fsid $fsid -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.client.admin.keyring ceph orch apply osd --all-available-devices
