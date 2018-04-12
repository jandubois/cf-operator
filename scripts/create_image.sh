#!/bin/bash -ex

function yq {
    ruby -rjson -ryaml -e "puts YAML.load_file(ARGV[0]).to_json" "$1" | jq -r "$2"
}

TOPLEVEL=$(git rev-parse --show-toplevel)
WORKSPACE="${TOPLEVEL}/workspace"
cd "${WORKSPACE}"

# Import stemcell as docker image
STEMCELL_NAME=$(yq stemcell/stemcell.MF .name)
STEMCELL_OS=$(yq stemcell/stemcell.MF .operating_system)
STEMCELL_VERSION=$(yq stemcell/stemcell.MF .version)

source "${TOPLEVEL}/scripts/bosh-env.sh"
export BOSH_DEPLOYMENT=postgres

RELEASE_NAME_AND_VERSION=$(bosh deployment --json | jq -r .Tables[0].Rows[0].release_s)

COMPILED_RELEASE=$(ls -1t ${RELEASE_NAME_AND_VERSION/\//-}-$STEMCELL_OS-${STEMCELLVERSION}* | head -1)

rm -rf release/
mkdir release
tar xfz ${COMPILED_RELEASE} -C release

rm -rf docker/
mkdir -p docker/vcap

DEPLOYMENT_MF=manifest-int.yml

PGADMIN_PASSWORD=changeme
bosh int manifest.yml -v pgadmin_database_password=${PGADMIN_PASSWORD} > ${DEPLOYMENT_MF}

for JOB in $(yq release/release.MF .jobs[].name); do
    mkdir -p docker/vcap/jobs-src/${JOB}
    tar xfz release/jobs/${JOB}.tgz -C docker/vcap/jobs-src/${JOB}
    ruby ${TOPLEVEL}/scripts/erb_expander.rb ${DEPLOYMENT_MF} docker/vcap ${JOB}
done

for PACKAGE in $(yq release/release.MF .compiled_packages[].name); do
    mkdir -p docker/vcap/packages/${PACKAGE}
    tar xfz release/compiled_packages/${PACKAGE}.tgz -C docker/vcap/packages/${PACKAGE}
done

mkdir -p docker/vcap/monit
echo "vcap:random-password" > docker/vcap/monit/monit.user

cat <<'EOF' > docker/entrypoint.sh
#!/bin/sh
for PRESTART in /var/vcap/jobs/*/bin/pre-start; do
    ${PRESTART}
done
/etc/sv/monit/run
EOF
chmod +x docker/entrypoint.sh

cat <<EOF > docker/Dockerfile
FROM ${STEMCELL_NAME}:${STEMCELL_VERSION}
ADD vcap /var/vcap
ADD entrypoint.sh /
RUN chown -R root:vcap /var/vcap
ENTRYPOINT ["/entrypoint.sh"]
EOF

TAG=${RELEASE_NAME_AND_VERSION/\//:}
# strip "+dev.nnn" from version
docker build -t ${TAG%%+*} docker
