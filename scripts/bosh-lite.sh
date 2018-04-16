#!/bin/bash -e

CMD="${1:-}"
if [[ "${CMD}" != "create-env" && "${CMD}" != "delete-env" ]]; then
    echo "Use either 'create-env' or 'delete-env' subcommand"
    exit 1
fi

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"
mkdir -p "${WORKSPACE}"

if [[ "${CMD}" == "create-env" && -f "${WORKSPACE}/state.json" ]]; then
    echo "bosh-lite has already been set up"
    exit 1
fi

set -x

# Create new bosh environment
bosh ${CMD} "${TOPLEVEL}/src/bosh-deployment/bosh.yml" \
  --state "${TOPLEVEL}/workspace/state.json" \
  -o "${TOPLEVEL}/src/bosh-deployment/virtualbox/cpi.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/virtualbox/outbound-network.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/bosh-lite.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/bosh-lite-runc.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/jumpbox-user.yml" \
  --vars-store "${TOPLEVEL}/workspace/creds.yml" \
  -v director_name="Bosh Lite Director" \
  -v internal_ip=192.168.50.6 \
  -v internal_gw=192.168.50.1 \
  -v internal_cidr=192.168.50.0/24 \
  -v outbound_network_name=NatNetwork

if [[ "${CMD}" == "create-env" ]]; then
    CLOUDCONFIG="${WORKSPACE}/cloud-config.yml"
    bosh int "${TOPLEVEL}/src/bosh-deployment/warden/cloud-config.yml"  -o /dev/stdin <<EOF > "${CLOUDCONFIG}"
- type: replace
  path: /disk_types/name=default/disk_size
  value: 10240
EOF
    source "${TOPLEVEL}/scripts/bosh-env.sh"
    bosh update-cloud-config -n "${CLOUDCONFIG}"
fi
