#!/bin/bash -e

CMD="${1:-}"
if [[ "${CMD}" != "create-env" && "${CMD}" != "delete-env" ]]; then
    echo "Use either 'create-env' or 'delete-env' subcommand"
    exit 1
fi

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"

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

#export BOSH_CLIENT=admin
#export BOSH_CLIENT_SECRET=`bosh int "{TOPLEVEL}/workspace/creds.yml" --path /admin_password`
if [[ "${CMD}" == "create-env" ]]; then
    source "${TOPLEVEL}/scripts/bosh-env.sh"
    bosh alias-env ${BOSH_ENVIRONMENT} -e 192.168.50.6 --ca-cert <(bosh int "${TOPLEVEL}/workspace/creds.yml" --path /director_ssl/ca)
    bosh update-cloud-config -n "${TOPLEVEL}/src/bosh-deployment/warden/cloud-config.yml"
fi
