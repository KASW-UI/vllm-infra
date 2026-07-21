ARG UBUNTU_VERSION=22.04
ARG PYTHON_VERSION=3.12.10
ARG TORCH_VERSION=2.11.0

FROM ubuntu:${UBUNTU_VERSION}

ARG PYTHON_VERSION
ARG TORCH_VERSION

LABEL project="cpu-vllm-infra"
LABEL python="${PYTHON_VERSION}"
LABEL torch="${TORCH_VERSION}+cpu"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc-12 g++-12 \
    ninja-build \
    make git git-lfs \
    curl wget ca-certificates \
    libnuma-dev libtcmalloc-minimal4 numactl \
    python3.12 python3.12-venv python3.12-dev \
    ffmpeg libsm6 libxext6 libgl1 \
    vim tmux htop btop \
    jq ripgrep fd-find bat fzf \
    libssl-dev libffi-dev zlib1g-dev \
    openssh-client \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100 && \
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 100 && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 100

RUN groupadd -g 1000 dev && \
    useradd -m -u 1000 -g dev -s /bin/bash dev && \
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

RUN mkdir -p /workspace/vllm /home/dev/.config/cpu-vllm-infra
COPY --chown=dev:dev configs/torch.env /home/dev/.config/cpu-vllm-infra/torch.env
COPY --chown=dev:dev configs/vllm.env /home/dev/.config/cpu-vllm-infra/vllm.env
COPY --chown=dev:dev configs/docker.env /home/dev/.config/cpu-vllm-infra/docker.env

RUN mkdir -p /workspace/scripts
COPY --chown=dev:dev scripts/ /workspace/scripts/

COPY --chown=dev:dev docker/entrypoint.sh /usr/local/bin/entrypoint.sh
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER dev

ENV CC=gcc-12
ENV CXX=g++-12

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
