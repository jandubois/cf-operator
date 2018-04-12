#!/bin/bash -ex

function yq {
    ruby -rjson -ryaml -e "puts YAML.load_file(ARGV[0]).to_json" "$1" | jq -r "$2"
}

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"
cd "${WORKSPACE}"

# Download latest stemcell
STEMCELL_URL=$(curl -s --head https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent | perl -ne '/^location: (\S+)/ && print $1')
STEMCELL_TARBALL=${STEMCELL_URL##*/}
if [ -f /tmp/${STEMCELL_TARBALL} ]; then
    cp /tmp/${STEMCELL_TARBALL} .
else
    wget ${STEMCELL_URL}
    cp ${STEMCELL_TARBALL} /tmp
fi

rm -rf stemcell
mkdir stemcell
tar xvfz ${STEMCELL_TARBALL} -C stemcell/

# Import stemcell as docker image
STEMCELL_NAME=$(yq stemcell/stemcell.MF .name)
STEMCELL_VERSION=$(yq stemcell/stemcell.MF .version)
docker import stemcell/image ${STEMCELL_NAME}:${STEMCELL_VERSION}

source "${TOPLEVEL}/scripts/bosh-env.sh"
bosh upload-stemcell ${STEMCELL_TARBALL}
