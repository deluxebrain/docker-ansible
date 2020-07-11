
SHELL=/bin/bash

COMMIT					?= $(shell git rev-parse HEAD)
NOW						?= $(shell date --rfc-3339=seconds --utc)
DISTRO_NAME				?= ubuntu
DISTRO_VERSION			?= bionic
DOCKER_REGISTRY			:= dockerhub.com
IMAGE_DIR				:= images
IMAGE_REPO				:= deluxebrain
IMAGE_TITLE				:= ansible
# VERSION 				?= $(shell cat VERSION | head -n1)

DOCKERFILE_PATH			:= $(IMAGE_DIR)/Dockerfile.${DISTRO_NAME}-${DISTRO_VERSION}
IMAGE_NAME				:= ${IMAGE_TITLE}-${DISTRO_NAME}:${DISTRO_VERSION}

# TODO
# bump-major
# bump-minor
# publish --> Takes in version

.PHONY: build
build: current_version = $(tag_version)
build: .build.target
.build.target: .bump-version.target $(DOCKERFILE_PATH)
	$(eval $(call bump-version, new_version, $(current_version)))
	$(info Building version $(new_version))
	docker build -t $(IMAGE_NAME) \
		--label "org.opencontainers.image.created=$(NOW)" \
		--label "org.opencontainers.image.revision=$(COMMIT)" \
		--label "org.opencontainers.image.title=$(IMAGE_TITLE)" \
		--label "org.opencontainers.image.version=v$(new_version)" \
		-f $(DOCKERFILE_PATH) \
		.
	docker image prune -f
	@touch $@

.PHONY: publish
publish: BUMP_TEMPLATE = "$$major.$$minor.$$(( ++patch ))"
publish: .publish.target
.publish.target: .bump-version.target
	@echo "Publish version: $(VERSION)"
	@touch $@

.PHONY: clean
clean:
	rm -f .*.target
	docker system prune -f

.PHONY: show
show: FORMAT = $(show_format)
show:
	docker inspect $(IMAGE_NAME) --format '$(FORMAT)'

.PHONY: bump-patch
bump-patch: BUMP_TEMPLATE = "$$major.$$minor.$$(( ++patch ))"
bump-patch:
	$(eval version := $(shell \
		IFS=. read -r major minor patch <<< $(TAG_VERSION); \
		echo "$(BUMP_TEMPLATE)"))
	@echo "$(version)"

.DEFAULT_GOAL := help
.PHONY: help

.PHONY: foo
foo:
	$(eval $(call bump-version, version, $(version)))
	@echo $(version)

# Helper functions

define show_format =
{{ range $$k, $$v := .Config.Labels -}} \
{{ $$k }} = {{ $$v }}{{ println }} \
{{- end }}
endef

# Get current version from the git tags
# Default to 0.0.0
define tag_version =
$(shell (( `git tag | grep "^v.*" | wc -l` > 0 )) && \
	git describe | grep "^v.*" | cut -d'v' -f2 || \
	echo "0.0.0")
endef

# Generate patch bump from current version
define bump-version =
$(1) = $(shell IFS=. read -r major minor patch <<< $(2); \
	echo "$$major.$$minor.$$(( ++patch ))")
endef
