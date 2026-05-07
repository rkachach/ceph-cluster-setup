#!/usr/bin/env bash
set -e

echo "===== Ceph Bootstrap Script Starting ====="

export PATH=/root/bin:$PATH
mkdir -p /root/bin
mkdir -p /etc/ceph

export INTERFACE="${INTERFACE:-ens3}"
export NETWORK_INTERFACE_TYPE="${NETWORK_INTERFACE_TYPE:-ipv4}"

########################################
# 1. Setup cephadm
########################################
echo "[INFO] Setting up cephadm..."
echo "[DEBUG] USE_LOCAL_CEPHADM='${USE_LOCAL_CEPHADM:-}' CEPH_DEV_FOLDER='${CEPH_DEV_FOLDER:-}' IMAGE='${IMAGE}' INTERFACE='${INTERFACE}' NETWORK_INTERFACE_TYPE='${NETWORK_INTERFACE_TYPE}'"

if [ "${USE_LOCAL_CEPHADM,,}" = "true" ]; then
  echo "[INFO] Using local cephadm from dev folder"

  if [ -z "${CEPH_DEV_FOLDER:-}" ]; then
    echo "[ERROR] CEPH_DEV_FOLDER not set"
    exit 1
  fi

  cp -f /mnt/${CEPH_DEV_FOLDER}/src/cephadm/cephadm /root/bin/cephadm
else
  echo "[INFO] Extracting cephadm from image: ${IMAGE}"

  if [ -n "${REGISTRY_USERNAME:-}" ] && [ -n "${REGISTRY_PASSWORD:-}" ]; then
    echo "[INFO] Logging into registry ${REGISTRY_URL}"
    podman login "${REGISTRY_URL}" -u "${REGISTRY_USERNAME}" -p "${REGISTRY_PASSWORD}"
  else
    echo "[INFO] No registry credentials provided; skipping podman login"
  fi

  CID=$(podman create "${IMAGE}")
  podman cp ${CID}:/usr/sbin/cephadm /root/bin/cephadm
  podman rm ${CID}
fi

chmod a+rx /root/bin/cephadm
echo "[INFO] cephadm ready: $(which cephadm)"

########################################
# 2. Prepare registry auth for cephadm
########################################
REGISTRY_ARGS=""

if [ -n "${REGISTRY_USERNAME:-}" ] && [ -n "${REGISTRY_PASSWORD:-}" ]; then
  echo "[INFO] Creating registry auth JSON"

  cat <<EOF > /root/registry-login.json
{
  "url": "${REGISTRY_URL}",
  "username": "${REGISTRY_USERNAME}",
  "password": "${REGISTRY_PASSWORD}"
}
EOF

  REGISTRY_ARGS="--registry-json /root/registry-login.json"
else
  echo "[INFO] No registry credentials provided; skipping registry auth JSON"
fi

########################################
# 3. Optional IBM license acceptance
########################################
LICENSE_ARGS=""

if [[ "${IMAGE}" == cp.icr.io/cp/ibm-ceph/* || "${IMAGE}" == cp.stg.icr.io/cp/ibm-ceph/* ]]; then
  echo "[INFO] IBM Storage Ceph image detected; enabling automatic license acceptance"
  LICENSE_ARGS="--automatically-accept-license"
else
  echo "[INFO] Non-IBM registry image detected; skipping license auto-accept flag"
fi

########################################
# 4. Get MON IP using requested interface
########################################
get_mon_ip() {
  local mon_ip

  if [ "${NETWORK_INTERFACE_TYPE}" = "ipv6" ]; then
    mon_ip=$(ip a show "${INTERFACE}" | grep 'inet6 ' | grep -v 'fe80' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
  else
    mon_ip=$(ip a show "${INTERFACE}" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
  fi

  if [ -z "${mon_ip}" ]; then
    mon_ip=$(ip a show "${INTERFACE}" | grep 'inet6 ' | grep -v 'fe80' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
  fi

  if [ -z "${mon_ip}" ]; then
    mon_ip=$(ip a show "${INTERFACE}" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
  fi

  echo "${mon_ip}"
}

mon_ip=$(get_mon_ip)

if [ -z "${mon_ip}" ]; then
  echo "[ERROR] Could not detect MON IP on interface ${INTERFACE}"
  ip a
  exit 1
fi

echo "[INFO] MON IP detected: ${mon_ip}"

########################################
# 5. Bootstrap cluster
########################################
echo "[INFO] Running cephadm bootstrap"

SHARED_CEPH_ARGS=""
if [ -n "${CEPH_DEV_FOLDER:-}" ]; then
  SHARED_CEPH_ARGS="--shared_ceph_folder /mnt/${CEPH_DEV_FOLDER}"
fi

python3 /root/bin/cephadm --image "${IMAGE}" bootstrap \
  --mon-ip "${mon_ip}" \
  --initial-dashboard-password "${ADMIN_PASSWORD}" \
  ${REGISTRY_ARGS} \
  ${LICENSE_ARGS} \
  ${SHARED_CEPH_ARGS} \
  --allow-fqdn-hostname \
  --dashboard-password-noupdate \
  --skip-monitoring-stack \
  --no-cleanup-on-failure

########################################
# 6. Add hosts
########################################
echo "[INFO] Adding hosts to cluster"

fsid=$(awk '/fsid/ {print $3}' /etc/ceph/ceph.conf)

for number in $(seq 1 $((NODES-1))); do
  node_name="${NODE_PREFIX}-node-${number}"

  if [ "${NETWORK_INTERFACE_TYPE}" = "ipv6" ]; then
    node_ip="${IPV6_PREFIX}::$(printf '%x' $((NODE_IP_OFFSET + number)))"
  else
    node_ip="${IP_PREFIX}.10${number}"
  fi

  echo "[INFO] Adding host ${node_name} (${node_ip})"

  ssh-copy-id -f -i /etc/ceph/ceph.pub \
    -o StrictHostKeyChecking=no root@${node_name}

  python3 /root/bin/cephadm shell --fsid "${fsid}" \
    -c /etc/ceph/ceph.conf \
    -k /etc/ceph/ceph.client.admin.keyring \
    ceph orch host add "${node_name}" "${node_ip}"
done

########################################
# 7. Apply OSDs
########################################
echo "[INFO] Applying OSDs on all available devices"

python3 /root/bin/cephadm shell --fsid "${fsid}" \
  -c /etc/ceph/ceph.conf \
  -k /etc/ceph/ceph.client.admin.keyring \
  ceph orch apply osd --all-available-devices

echo "===== Ceph Bootstrap Completed Successfully ====="
