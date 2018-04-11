#!/bin/bash

set -ex

function yq {
    ruby -rjson -ryaml -e "puts YAML.load_file(ARGV[0]).to_json" "$1" | jq -r "$2"
}

TOPLEVEL=$(git rev-parse --show-toplevel)

cd "${TOPLEVEL}/workspace"
rm -rf *

# Download latest stemcell
STEMCELL_URL=$(curl -s --head https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent | perl -ne '/^location: (\S+)/ && print $1')
if [ -f /tmp/${STEMCELL_URL##*/} ]; then
    cp /tmp/${STEMCELL_URL##*/} .
else
    wget ${STEMCELL_URL}
    cp ${STEMCELL_URL##*/} /tmp
fi

# Extract stemcell
mkdir stemcell
tar xvfz ${STEMCELL_URL##*/} -C stemcell/

# Import stemcell as docker image
STEMCELL_NAME=$(yq stemcell/stemcell.MF .name)
STEMCELL_OS=$(yq stemcell/stemcell.MF .operating_system)
STEMCELL_VERSION=$(yq stemcell/stemcell.MF .version)
docker import stemcell/image ${STEMCELL_NAME}:${STEMCELL_VERSION}

# Create new bosh environment
bosh create-env ${TOPLEVEL}/src/bosh-deployment/bosh.yml \
  --state ${TOPLEVEL}/workspace/state.json \
  -o ${TOPLEVEL}/src/bosh-deployment/virtualbox/cpi.yml \
  -o ${TOPLEVEL}/src/bosh-deployment/virtualbox/outbound-network.yml \
  -o ${TOPLEVEL}/src/bosh-deployment/bosh-lite.yml \
  -o ${TOPLEVEL}/src/bosh-deployment/bosh-lite-runc.yml \
  -o ${TOPLEVEL}/src/bosh-deployment/jumpbox-user.yml \
  --vars-store {TOPLEVEL}/workspace/creds.yml \
  -v director_name="Bosh Lite Director" \
  -v internal_ip=192.168.50.6 \
  -v internal_gw=192.168.50.1 \
  -v internal_cidr=192.168.50.0/24 \
  -v outbound_network_name=NatNetwork

bosh alias-env vbox -e 192.168.50.6 --ca-cert <(bosh int {TOPLEVEL}/workspace/creds.yml --path /director_ssl/ca)
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int {TOPLEVEL}/workspace/creds.yml --path /admin_password`
export BOSH_ENVIRONMENT=vbox
bosh update-cloud-config -n ${TOPLEVEL}/src/bosh-deployment/warden/cloud-config.yml

# Create deployment manifest for postgres-release
wget https://raw.githubusercontent.com/cloudfoundry/postgres-release/develop/templates/postgres.yml
wget https://raw.githubusercontent.com/cloudfoundry/postgres-release/develop/templates/operations/set_properties.yml
# our cloud-config doesn't have "small" VMs nor predefined disk types
cat <<EOF >> set_properties.yml

- type: replace
  path: /instance_groups/name=postgres/vm_type
  value: default

- type: remove
  path: /instance_groups/name=postgres/persistent_disk_type

- type: replace
  path: /instance_groups/name=postgres/persistent_disk?
  value: 10240
EOF
bosh int postgres.yml -o set_properties.yml > manifest.yml

# Deploy latest postgres-release and download compiled packages
bosh upload-stemcell ${STEMCELL_URL##*/}
bosh upload-release https://bosh.io/d/github.com/cloudfoundry/postgres-release

export BOSH_DEPLOYMENT=postgres

PGADMIN_PASSWORD=changeme
bosh deploy -n -v pgadmin_database_password=${PGADMIN_PASSWORD} manifest.yml

RELEASE_NAME_AND_VERSION=$(bosh deployment --json | jq -r .Tables[0].Rows[0].release_s)
bosh export-release ${RELEASE_NAME_AND_VERSION} ${STEMCELL_OS}/${STEMCELL_VERSION}
