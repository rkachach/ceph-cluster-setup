#!/usr/bin/env bash
set -x
export IMAGE="quay.ceph.io/ceph-ci/ceph:main"
export INTERFACE="{% if network_interface_name is defined %}{{ network_interface_name }}{% else %}ens3{% endif %}"

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

get_mon_ip() {
  local mon_ip
  mon_ip=$(ip a show $INTERFACE | grep 'inet6 ' | grep -v 'fe80' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
  # If no IPv6 found, check for IPv4
  if [ -z "$mon_ip" ]; then
    mon_ip=$(ip a show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
  fi
  echo "$mon_ip"
}

mon_ip=$(get_mon_ip)
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
