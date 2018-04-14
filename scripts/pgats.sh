#!/bin/bash -e

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"

source "${TOPLEVEL}/scripts/bosh-env.sh"
export PGATS_CONFIG="${WORKSPACE}/pgats.yml"

function creds {
    bosh int "${HOME}/.bosh/config" --path "/environments/alias=${BOSH_ENVIRONMENT}/$1"
}

bosh int /dev/stdin -v target="$(creds url)" -v username="$(creds username)" -v password="$(creds password)" \
         --var-file ca_cert=<(creds ca_cert) <<EOF > "${PGATS_CONFIG}"
---
bosh:
  target: ((target))
  username: ((username))
  password: ((password))
  director_ca_cert: ((ca_cert))
cloud_configs:
  default_azs: [z1]
  default_networks:
  - name: default
  default_persistent_disk_type: default
  default_vm_type: default
EOF

./src/github.com/cloudfoundry/postgres-release/src/acceptance-tests/scripts/test "$@"
