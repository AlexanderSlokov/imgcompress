REGISTRY ?= docker.io/karimz1
IMAGE ?= imgcompress
TAG ?= latest
DHI_YAML_FILE ?= docker/image/0.6.1-dhi.yaml
CLOUD_BUILDER=

# Build image with sbom and provenance,
# good for Docker Scout to indexing layers and attestation.
DHI_build:
	docker buildx build . -f $(DHI_YAML_FILE) \
	--platform linux/amd64,linux/arm64 \
	--sbom=generator=dhi.io/scout-sbom-indexer:1 \
	--provenance=1 \
	-t $(REGISTRY)/$(IMAGE):$(TAG)


# Use Docker Hub Cloudbuild for faster build.
# Need a Docker Hub account and must init a Cloud Builder first.
DHI_cloud_build:
	docker buildx build . -f $(DHI_YAML_FILE) \
	--builder $(CLOUD_BUILDER) \
	--platform linux/amd64,linux/arm64 \
	--sbom=generator=dhi.io/scout-sbom-indexer:1 \
	--provenance=1 \
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
	docker compose -f docker-compose.test.yml up --build -d
	docker compose -f docker-compose.test.yml logs -f test-runner || true
	@exit_code=$$(docker inspect --format='{{.State.ExitCode}}' imgcompress-test-runner-1 2>/dev/null || echo 1); \
	docker compose -f docker-compose.test.yml down 2>/dev/null || true; \
	exit $$exit_code
