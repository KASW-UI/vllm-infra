ARG UBUNTU_VERSION=24.04
ARG PYTHON_VERSION=3.12.13
ARG TORCH_VERSION=2.11.0

FROM ubuntu:${UBUNTU_VERSION}

ARG PYTHON_VERSION
ARG TORCH_VERSION

LABEL project="cpu-vllm-infra"
LABEL python="${PYTHON_VERSION}"
LABEL torch="${TORCH_VERSION}+cpu"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl wget \
    gcc-13 g++-13 \
    make git git-lfs \
    ninja-build \
    python3.12 python3.12-venv python3.12-dev \
    libssl-dev libffi-dev zlib1g-dev \
    libnuma-dev libtcmalloc-minimal4 numactl \
    ffmpeg libsm6 libxext6 libgl1 \
    vim tmux htop btop \
    jq ripgrep fd-find bat fzf \
    zsh \
    openssh-client sudo \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100 && \
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 100 && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 100

RUN userdel -r ubuntu 2>/dev/null || true && \
    groupadd -g 1000 dev 2>/dev/null || true && \
    useradd -m -u 1000 -g dev -s /bin/zsh dev && \
    echo 'dev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER dev
ENV HOME=/home/dev
WORKDIR /workspace

RUN python3.12 -m venv /workspace/.venv
ENV PATH="/workspace/.venv/bin:${PATH}"

RUN pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir cmake>=3.26.1

COPY --chown=dev:dev env/requirements.lock /tmp/requirements.lock

RUN pip install --no-cache-dir -r /tmp/requirements.lock \
    --index-url https://download.pytorch.org/whl/cpu \
    --extra-index-url https://pypi.org/simple

ENV CC=gcc-13
ENV CXX=g++-13

RUN mkdir -p /workspace/vllm

COPY .build/ /tmp/build/

USER root
RUN if [ -f /tmp/build/opencode ]; then \
        cp /tmp/build/opencode /usr/local/bin/opencode && \
        chmod +x /usr/local/bin/opencode; \
    fi && \
    mkdir -p /home/dev/.config/opencode && \
    if [ -d /tmp/build/skills ]; then \
        cp -r /tmp/build/skills/ /home/dev/.config/opencode/skills/; \
    fi && \
    if [ -f /tmp/build/opencode.jsonc ]; then \
        cp /tmp/build/opencode.jsonc /home/dev/.config/opencode/opencode.jsonc; \
    fi && \
    chown -R dev:dev /home/dev/.config/opencode && \
    rm -rf /tmp/build
USER dev

RUN mkdir -p /home/dev/.config/cpu-vllm-infra
COPY --chown=dev:dev configs/torch.env /home/dev/.config/cpu-vllm-infra/torch.env
COPY --chown=dev:dev configs/vllm.env /home/dev/.config/cpu-vllm-infra/vllm.env
COPY --chown=dev:dev configs/docker.env /home/dev/.config/cpu-vllm-infra/docker.env

RUN mkdir -p /workspace/scripts
COPY --chown=dev:dev scripts/ /workspace/scripts/

COPY --chown=dev:dev docker/entrypoint.sh /usr/local/bin/entrypoint.sh
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER dev

ENV PATH="/usr/local/bin:${PATH}"
ENV SHELL=/bin/zsh

COPY --chown=dev:dev config/.zshrc /home/dev/.zshrc

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
