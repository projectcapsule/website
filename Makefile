apidoc: apidocs-gen
	$(APIDOCS_GEN) crdoc --resources config/crd/bases --output docs/content/general/crds-apis.md --template docs/template/reference-cr.tmpl
