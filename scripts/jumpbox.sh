#!/bin/bash -e

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"

KEYFILE="${WORKSPACE}/jumpbox.key"

bosh int "${WORKSPACE}/creds.yml" --path /jumpbox_ssh/private_key > "${KEYFILE}"
chmod 600 "${KEYFILE}"

source "${TOPLEVEL}/scripts/bosh-env.sh"

set -x
ssh jumpbox@${BOSH_ENVIRONMENT} -i "${KEYFILE}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
