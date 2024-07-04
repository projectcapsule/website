# Temporary directory for cloning

fetch-capsule: REF      ?= main
fetch-capsule: REPO_URL ?= https://github.com/projectcapsule/capsule.git
fetch-capsule: fetch

fetch-capsule-proxy: REF      ?= main
fetch-capsule-proxy: REPO_URL ?= https://github.com/projectcapsule/capsule-proxy.git
fetch-capsule-proxy: fetch

fetch:
	@echo "Cloning repository..."
	git clone $(REPO_URL) $(TARGET_DIR)
	@echo "Checking out $(REF)..."
	cd $(TARGET_DIR) && git checkout $(REF)
	@echo "Repository cloned to $(TARGET_DIR) and switched to $(REF)"

apidocs: apidocs-capsule apidocs-capsule-proxy

apidocs-capsule: TARGET_DIR := $(shell mktemp -d)
apidocs-capsule: apidocs-gen fetch-capsule
	$(APIDOCS_GEN) crdoc --resources $(TARGET_DIR)/config/crd/bases --output content/en/docs/reference.md --template templates/capsule-crds.tmpl

apidocs-capsule-proxy: TARGET_DIR      := $(shell mktemp -d)
apidocs-capsule-proxy: apidocs-gen fetch-capsule-proxy
	$(APIDOCS_GEN) crdoc --resources $(TARGET_DIR)/charts/capsule-proxy/crd --output content/en/docs/addons/capsule-proxy/reference.md --template templates/capsule-proxy-crds.tmpl

APIDOCS_GEN         := $(shell pwd)/bin/crdoc
APIDOCS_GEN_VERSION := latest
apidocs-gen: ## Download crdoc locally if necessary.
	$(call go-install-tool,$(APIDOCS_GEN),fybrik.io/crdoc@$(APIDOCS_GEN_VERSION))

# go-install-tool will 'go install' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-install-tool
@[ -f $(1) ] || { \
set -e ;\
GOBIN=$(PROJECT_DIR)/bin go install $(2) ;\
}
endef
