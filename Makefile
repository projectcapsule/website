apidocs: apidocs-capsule apidocs-capsule-proxy

define fetch-repo
	@echo "Cloning repository..."
	git clone $(1) $(2) --branch $(3)
	@echo "Repository cloned to $(2) and switched to $(3)"
endef

fetch-capsule: REF      ?= main
fetch-capsule: REPO_URL ?= https://github.com/projectcapsule/capsule.git
fetch-capsule:
	$(call fetch-repo,$(REPO_URL),$(TARGET_DIR),$(REF))

fetch-capsule-proxy: REF      ?= main
fetch-capsule-proxy: REPO_URL ?= https://github.com/projectcapsule/capsule-proxy.git
fetch-capsule-proxy:
	$(call fetch-repo,$(REPO_URL),$(TARGET_DIR),$(REF))

apidocs-capsule: TARGET_DIR := $(shell mktemp -d)
apidocs-capsule: apidocs-gen fetch-capsule
	find $(TARGET_DIR)/charts/capsule/crds -type f ! -name '*.yaml' -delete
	$(APIDOCS_GEN) crdoc --resources $(TARGET_DIR)/charts/capsule/crds --output content/en/docs/reference.md --template templates/crds.tmpl

apidocs-capsule-proxy: TARGET_DIR      := $(shell mktemp -d)
apidocs-capsule-proxy: apidocs-gen fetch-capsule-proxy
	find $(TARGET_DIR)/charts/capsule-proxy/crds -type f ! -name '*.yaml' -delete
	$(APIDOCS_GEN) crdoc --resources $(TARGET_DIR)/charts/capsule-proxy/crds --output content/en/docs/proxy/reference.md --template templates/crds.tmpl

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
