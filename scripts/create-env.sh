#!/bin/bash -e

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"
mkdir -p "${WORKSPACE}"
rm -rf "${WORKSPACE}/*"

set -x

bosh int "${TOPLEVEL}/src/bosh-deployment/bosh.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/virtualbox/cpi.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/virtualbox/outbound-network.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/bosh-lite.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/bosh-lite-runc.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/jumpbox-user.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/uaa.yml" \
  -o "${TOPLEVEL}/src/bosh-deployment/credhub.yml" \
  -o /dev/stdin \
  --vars-store "${WORKSPACE}/creds.yml" \
  -v director_name="Bosh-Lite-Director" \
  -v internal_ip=192.168.50.6 \
  -v internal_gw=192.168.50.1 \
  -v internal_cidr=192.168.50.0/24 \
  -v outbound_network_name=NatNetwork \
  <<EOF > "${WORKSPACE}/bosh.yml"
- type: replace
  path: /instance_groups/name=bosh/properties/director/user_management
  value:
    provider: local
    local:
      users:
      - name: admin
        password: ((admin_password))
      - name: hm
        password: ((hm_password))
EOF

bosh create-env --state "${WORKSPACE}/state.json" "${WORKSPACE}/bosh.yml"

CLOUDCONFIG="${WORKSPACE}/cloud-config.yml"
bosh int "${TOPLEVEL}/src/bosh-deployment/warden/cloud-config.yml"  -o /dev/stdin <<EOF > "${CLOUDCONFIG}"
- type: replace
  path: /disk_types/name=default/disk_size
  value: 10240
EOF
source "${TOPLEVEL}/scripts/bosh-env.sh"
bosh update-cloud-config -n "${CLOUDCONFIG}"
