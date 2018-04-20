.PHONY: create-bosh-lite delete-bosh-lite stemcell compile image all jumpbox test pgats clean

create-env:
	./scripts/create-env.sh

delete-env:
	./scripts/delete-env.sh

stemcell:
	./scripts/stemcell.sh

compile:
	./scripts/compile-release.sh

image:
	./scripts/create-image.sh

all: create-env stemcell compile image

jumpbox:
	./scripts/jumpbox.sh

test:
	./scripts/test.sh

pgats:
	./scripts/pgats.sh

clean: delete-env
	rm -rf workspace/*
