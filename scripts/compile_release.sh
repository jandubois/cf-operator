#!/bin/bash -ex

function yq {
    ruby -rjson -ryaml -e "puts YAML.load_file(ARGV[0]).to_json" "$1" | jq -r "$2"
}

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"
cd "${WORKSPACE}"

# Create deployment manifest for postgres-release
wget https://raw.githubusercontent.com/cloudfoundry/postgres-release/develop/templates/postgres.yml -O postgres.yml
wget https://raw.githubusercontent.com/cloudfoundry/postgres-release/develop/templates/operations/set_properties.yml -O set_properties.yml
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

source "${TOPLEVEL}/scripts/bosh-env.sh"

# Deploy latest postgres-release and download compiled packages
bosh upload-release https://bosh.io/d/github.com/cloudfoundry/postgres-release

export BOSH_DEPLOYMENT=postgres

PGADMIN_PASSWORD=changeme
bosh deploy -n -v pgadmin_database_password=${PGADMIN_PASSWORD} manifest.yml

STEMCELL_OS=$(yq stemcell/stemcell.MF .operating_system)
STEMCELL_VERSION=$(yq stemcell/stemcell.MF .version)

RELEASE_NAME_AND_VERSION=$(bosh deployment --json | jq -r .Tables[0].Rows[0].release_s)
bosh export-release ${RELEASE_NAME_AND_VERSION} ${STEMCELL_OS}/${STEMCELL_VERSION}
