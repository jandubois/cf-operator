#!/bin/bash -ex

function yq {
    ruby -rjson -ryaml -e "puts YAML.load_file(ARGV[0]).to_json" "$1" | jq -r "$2"
}

TOPLEVEL=$(git rev-parse --show-toplevel)
POSTGRES_RELEASE="${TOPLEVEL}/src/github.com/cloudfoundry/postgres-release"

WORKSPACE="${TOPLEVEL}/workspace"
cd "${WORKSPACE}"

RELEASE_TARBALL="${WORKSPACE}/postgress-release.tgz"
bosh create-release --force --dir="${POSTGRES_RELEASE}" --tarball="${RELEASE_TARBALL}"

source "${TOPLEVEL}/scripts/bosh-env.sh"
bosh upload-release "${RELEASE_TARBALL}"

# Create deployment manifest for postgres-release
# our cloud-config doesn't have "small" VMs nor predefined disk types
MANIFEST="${WORKSPACE}/manifest.yml"
bosh int "${POSTGRES_RELEASE}/templates/postgres.yml" -o "${POSTGRES_RELEASE}/templates/operations/set_properties.yml" -o /dev/stdin <<EOF > "${MANIFEST}"
- type: replace
  path: /instance_groups/name=postgres/vm_type
  value: default

- type: remove
  path: /instance_groups/name=postgres/persistent_disk_type

- type: replace
  path: /instance_groups/name=postgres/persistent_disk?
  value: 10240
EOF

export BOSH_DEPLOYMENT=postgres

PGADMIN_PASSWORD=changeme
bosh deploy -n -v pgadmin_database_password=${PGADMIN_PASSWORD} "${MANIFEST}"

STEMCELL_OS=$(yq stemcell/stemcell.MF .operating_system)
STEMCELL_VERSION=$(yq stemcell/stemcell.MF .version)

RELEASE_NAME_AND_VERSION=$(bosh deployment --json | jq -r .Tables[0].Rows[0].release_s)
bosh export-release ${RELEASE_NAME_AND_VERSION} ${STEMCELL_OS}/${STEMCELL_VERSION}
