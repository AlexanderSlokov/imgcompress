REGISTRY ?= docker.io/karimz1
IMAGE ?= imgcompress
TAG ?= latest
DHI_YAML_FILE ?= atelier/image/0.6.1-dhi.yaml
DHI_DOCKERFILE ?= atelier/image/dhi.Dockerfile
ARTIFACT_IMAGE ?= $(REGISTRY)/$(IMAGE)-artifact-carrier
ARTIFACT_TAG ?= 0.6.1
CLOUD_BUILDER=

# ── DHI 2-Phase Build Workflow ──
# Phase 1: Build application files → push as OCI artifact (needs internet for pip/pnpm).
# Phase 2: DHI assembles hardened runtime from artifact + system packages.

# Phase 1: Build and push the artifact-carrier.
# After push, update the digest in $(DOCKER_YAML_FILE) under contents.artifacts.
# Ex: make artifact_push REGISTRY=docker.io/thanhzeus2016 CLOUD_BUILDER=cloud-thanhzeus2016-aleksandr-slokov-cloud-builder
artifact_push:
	docker buildx build . \
	--builder $(CLOUD_BUILDER) \
	--target artifact-carrier \
	--platform linux/amd64,linux/arm64 \
	--sbom=true \
	--provenance=mode=max \
	--push \
	-t $(ARTIFACT_IMAGE):$(ARTIFACT_TAG)

# Phase 2: Build hardened image from DHI yaml.
# Requires artifact_push to have been run first.
DHI_build:
	docker buildx build . -f $(DOCKER_YAML_FILE) \
	--platform linux/amd64,linux/arm64 \
	--sbom=true \
	--provenance=mode=max \
	--push \
	-t $(REGISTRY)/$(IMAGE):$(TAG)

# Use Docker Hub Cloudbuild for faster build.
# Need a Docker Hub account and must init a Cloud Builder first.
DHI_cloud_build:
	docker buildx build . -f $(DOCKER_YAML_FILE) \
	--builder $(CLOUD_BUILDER) \
	--platform linux/amd64,linux/arm64 \
	--sbom=generator=dhi.io/scout-sbom-indexer:1 \
	--provenance=1 \
	--push \
	-t $(REGISTRY)/$(IMAGE):$(TAG)

# Or you can build the Final Image with standard Dockerfile. 
# The reason is Docker Scout got confuse when it sees multiple Base Image.
# So we need a dedicated file for it.
DHI_dockerfile_cloud_build:
	docker buildx build . \
	-f $(DHI_DOCKERFILE) \
	--builder $(CLOUD_BUILDER) \
	--platform linux/amd64,linux/arm64 \
	--sbom=true \
	--provenance=mode=max \
	--push \
	-t $(REGISTRY)/$(IMAGE):$(TAG)

# Call Trivy to scan image for vulnerabilites.
# It is a best practice to check the image after you build it.
trivy:
	docker run --rm -v \
	/var/run/docker.sock:/var/run/docker.sock \
	aquasec/trivy:0.70.0@sha256:be1190afcb28352bfddc4ddeb71470835d16462af68d310f9f4bca710961a41e \
	image \
	--severity HIGH,CRITICAL \
	--format table \
	--output scan-result.log \
	$(REGISTRY)/$(IMAGE):$(TAG)

local_build:
	@bash runLocalDockerBuildTester.sh

# Run all Blackbox Tests (Integration + Playwright) using the devcontainer as runner.
# Cannot use --exit-code-from because it implies --abort-on-container-exit,
# which kills test-runner when the startup-test container (spawned via
# `docker run` inside the test suite) exits.
test_blackbox:
	docker compose -f atelier/docker-compose.test.yml up --build -d
	docker compose -f atelier/docker-compose.test.yml logs -f test-runner || true
	@exit_code=$$(docker inspect --format='{{.State.ExitCode}}' imgcompress-test-runner-1 2>/dev/null || echo 1); \
	docker compose -f atelier/docker-compose.test.yml down 2>/dev/null || true; \
	exit $$exit_code
