#!/bin/bash -e

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"

set -x
export CREDHUB_CLIENT=credhub-admin
export CREDHUB_SECRET=$(bosh int "${WORKSPACE}/bosh.yml" --path /instance_groups/name=bosh/jobs/name=uaa/properties/uaa/clients/${CREDHUB_CLIENT}/secret)
export CREDHUB_SERVER=192.168.50.6:8844
credhub login -s "$CREDHUB_SERVER" -u "$CREDHUB_USERNAME" -p "$CREDHUB_PASSWORD" --skip-tls-validation
