export BOSH_CA_CERT=`bosh int "$(git rev-parse --show-toplevel)/workspace/creds.yml" --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int "$(git rev-parse --show-toplevel)/workspace/creds.yml" --path /admin_password`
export BOSH_DEPLOYMENT=postgres
export BOSH_ENVIRONMENT=192.168.50.6
