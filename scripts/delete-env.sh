#!/bin/bash -ex

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"

bosh delete-env --state "${WORKSPACE}/state.json" "${WORKSPACE}/bosh.yml"
