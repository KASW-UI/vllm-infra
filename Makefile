.PHONY: build pull run shell verify healthcheck snapshot serve bench stop logs clean lock open-code

include env/versions.env
export

REGISTRY   ?= ghcr.io/kasw-ui/cpu-vllm-infra
IMAGE_NAME ?= cpu-vllm-infra
IMAGE_TAG  ?= ubuntu$(UBUNTU_VERSION)-torch$(TORCH_VERSION)

DOCKERFILE   := docker/Dockerfile
COMPOSE_FILE := deploy/docker/docker-compose.yml
CONTEXT      := .

VLLM_SRC    ?= /home/kasw/文档/GitHub/GPU-Project/vllm
OPENCODE_BIN ?= /home/kasw/.opencode/bin/opencode
OPENCODE_CFG ?= /home/kasw/.config/opencode

build:
	@echo "==> Preparing external files..."
	@mkdir -p .build
	@echo "==> Copying vllm source from $(VLLM_SRC)..."
	cp -r $(VLLM_SRC) .build/vllm
	@echo "==> Copying opencode..."
	cp $(OPENCODE_BIN) .build/opencode
	cp -r $(OPENCODE_CFG)/skills .build/skills
	cp $(OPENCODE_CFG)/opencode.jsonc .build/opencode.jsonc
	@echo "==> Building $(IMAGE_NAME):$(IMAGE_TAG)"
	docker build \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--build-arg TORCH_VERSION=$(TORCH_VERSION) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-f $(DOCKERFILE) \
		$(CONTEXT)
	@echo "==> Generating manifest.json"
	@docker inspect $(IMAGE_NAME):$(IMAGE_TAG) --format '{{json .}}' | \
		jq '{ \
			project: "cpu-vllm-infra", \
			image: "$(IMAGE_NAME):$(IMAGE_TAG)", \
			digest: .RepoDigests[0], \
			base_image: "ubuntu:$(UBUNTU_VERSION)", \
			built_at: .Created, \
			python: "$(PYTHON_VERSION)", \
			torch: "$(TORCH_VERSION)+cpu", \
			os: .Os, \
			architecture: .Architecture, \
			docker_version: .DockerVersion, \
			size: .Size \
		}' > manifest.json
	@echo "==> Cleaning up .build..."
	@rm -rf .build
	@echo "==> Build complete"
	@cat manifest.json

pull:
	@echo "==> Pulling $(REGISTRY):latest"
	docker pull $(REGISTRY):latest
	@echo "==> Tagging as $(IMAGE_NAME):$(IMAGE_TAG)"
	docker tag $(REGISTRY):latest $(IMAGE_NAME):$(IMAGE_TAG)
	@echo "==> Pull complete"

run:
	@echo "==> Starting container with compose"
	docker compose -f $(COMPOSE_FILE) up -d

shell:
	docker compose -f $(COMPOSE_FILE) exec vllm-dev bash

verify:
	docker compose -f $(COMPOSE_FILE) exec vllm-dev bash /workspace/scripts/verify.sh

healthcheck:
	docker compose -f $(COMPOSE_FILE) exec vllm-dev bash /workspace/scripts/healthcheck.sh

snapshot:
	docker compose -f $(COMPOSE_FILE) exec vllm-dev bash /workspace/scripts/snapshot.sh

serve:
	docker compose -f $(COMPOSE_FILE) exec vllm-dev bash /workspace/scripts/serve.sh

bench:
	docker compose -f $(COMPOSE_FILE) exec vllm-dev bash /workspace/scripts/bench.sh

open-code:
	docker compose -f $(COMPOSE_FILE) exec vllm-dev opencode

stop:
	docker compose -f $(COMPOSE_FILE) down

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

clean:
	docker compose -f $(COMPOSE_FILE) down -v --rmi local 2>/dev/null || true
	rm -rf .build manifest.json

lock:
	@echo "==> Generating requirements.lock"
	uv pip compile env/requirements.in \
		--index-url https://download.pytorch.org/whl/cpu \
		--extra-index-url https://pypi.org/simple \
		--index-strategy unsafe-best-match \
		--python-version $(PYTHON_VERSION) \
		-o env/requirements.lock
	@echo "==> Generating requirements-hash.lock"
	uv pip compile env/requirements.in \
		--index-url https://download.pytorch.org/whl/cpu \
		--extra-index-url https://pypi.org/simple \
		--index-strategy unsafe-best-match \
		--python-version $(PYTHON_VERSION) \
		--generate-hashes \
		-o env/requirements-hash.lock
	@echo "==> Lock files generated"
