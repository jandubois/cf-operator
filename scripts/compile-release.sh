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

bosh upload-release https://bosh.io/d/github.com/cloudfoundry-incubator/bpm-release

# Create deployment manifest for postgres-release
# our cloud-config doesn't have "small" VMs nor predefined disk types
MANIFEST="${WORKSPACE}/manifest.yml"
bosh int "${POSTGRES_RELEASE}/templates/postgres.yml" \
     -o "${POSTGRES_RELEASE}/templates/operations/set_properties.yml" \
     -o "${POSTGRES_RELEASE}/templates/operations/use_bpm.yml" \
     -o "${POSTGRES_RELEASE}/templates/operations/use_ssl.yml" \
     -o /dev/stdin <<'EOF' > "${MANIFEST}"
- type: replace
  path: /instance_groups/name=postgres/vm_type
  value: default

- type: replace
  path: /instance_groups/name=postgres/persistent_disk_type
  value: default

- type: replace
  path: /instance_groups/name=postgres/jobs/name=postgres/properties/databases/hooks?/pre_start?
  value: |
    #!/bin/bash
    echo pre-start hook

- type: replace
  path: /instance_groups/name=postgres/jobs/name=postgres/properties/databases/hooks?/post_start?
  value: |
    #!/bin/bash
    echo post-start hook starting
    ${PACKAGE_DIR}/bin/psql -U vcap -p ${PORT} -d postgres -c 'CREATE ROLE poststartuser WITH LOGIN'
    echo post-start hook done

- type: replace
  path: /instance_groups/name=postgres/jobs/name=postgres/properties/databases/hooks?/pre_stop?
  value: |
    #!/bin/bash
    echo pre-stop hook starting
    ${PACKAGE_DIR}/bin/psql -U vcap -p ${PORT} -d postgres -c 'CREATE ROLE prestopuser WITH LOGIN'
    echo pre-stop hook done

- type: replace
  path: /instance_groups/name=postgres/jobs/name=postgres/properties/databases/hooks?/post_stop?
  value: |
    #!/bin/bash
    echo post-stop hook
EOF

PGADMIN_PASSWORD=changeme
bosh deploy "${MANIFEST}" -n -v pgadmin_database_password=${PGADMIN_PASSWORD} -v postgres_host_or_ip=10.244.0.2 \
     --vars-store "${WORKSPACE}/deployment-vars.yml"

STEMCELL_OS=$(yq stemcell/stemcell.MF .operating_system)
STEMCELL_VERSION=$(yq stemcell/stemcell.MF .version)

RELEASE_NAME_AND_VERSION=$(bosh deployment --json | jq -r .Tables[0].Rows[0].release_s | grep postgres)
bosh export-release ${RELEASE_NAME_AND_VERSION} ${STEMCELL_OS}/${STEMCELL_VERSION}
