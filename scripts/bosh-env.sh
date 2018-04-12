export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int "$(git rev-parse --show-toplevel)/workspace/creds.yml" --path /admin_password`
export BOSH_ENVIRONMENT=cf-operator
