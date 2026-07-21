ARG UBUNTU_VERSION=22.04
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
    gcc-12 g++-12 \
    make git git-lfs \
    ninja-build \
    libssl-dev libffi-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev \
    liblzma-dev tk-dev libncursesw5-dev \
    libgdbm-dev libnss3-dev \
    libnuma-dev libtcmalloc-minimal4 numactl \
    ffmpeg libsm6 libxext6 libgl1 \
    vim tmux htop btop \
    jq ripgrep fd-find bat fzf \
    zsh \
    openssh-client sudo \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100 && \
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 100 && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 100

RUN curl -fsSL https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz -o /tmp/python.tar.xz && \
    cd /tmp && tar -xf python.tar.xz && cd Python-${PYTHON_VERSION} && \
    ./configure --enable-optimizations --prefix=/usr/local && \
    make -j$(nproc) && make altinstall && \
    rm -rf /tmp/Python-${PYTHON_VERSION} /tmp/python.tar.xz

RUN ln -sf /usr/local/bin/python$(echo ${PYTHON_VERSION} | cut -d. -f1,2) /usr/local/bin/python3 && \
    ln -sf /usr/local/bin/python3 /usr/local/bin/python

RUN update-alternatives --install /usr/bin/python python /usr/local/bin/python3 100 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3 100

RUN userdel -r ubuntu 2>/dev/null || true && \
    groupadd -g 1000 dev 2>/dev/null || true && \
    useradd -m -u 1000 -g dev -s /bin/zsh dev && \
    echo 'dev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER dev
ENV HOME=/home/dev
WORKDIR /workspace

RUN python3 -m venv /workspace/.venv
ENV PATH="/workspace/.venv/bin:${PATH}"

RUN pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir cmake>=3.26.1

COPY --chown=dev:dev env/requirements.lock /tmp/requirements.lock

RUN pip install --no-cache-dir -r /tmp/requirements.lock \
    --index-url https://download.pytorch.org/whl/cpu \
    --extra-index-url https://pypi.org/simple

COPY --chown=dev:dev .build/vllm /workspace/vllm
RUN pip install --no-cache-dir -e /workspace/vllm --no-build-isolation

COPY .build/ /tmp/build/
RUN if [ -f /tmp/build/opencode ]; then \
        sudo cp /tmp/build/opencode /usr/local/bin/opencode && \
        sudo chmod +x /usr/local/bin/opencode; \
    fi && \
    mkdir -p /home/dev/.config/opencode && \
    if [ -d /tmp/build/skills ]; then \
        cp -r /tmp/build/skills/ /home/dev/.config/opencode/skills/; \
    fi && \
    if [ -f /tmp/build/opencode.jsonc ]; then \
        cp /tmp/build/opencode.jsonc /home/dev/.config/opencode/opencode.jsonc; \
    fi && \
    rm -rf /tmp/build

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

ENV CC=gcc-12
ENV CXX=g++-12
ENV PATH="/usr/local/bin:${PATH}"
ENV SHELL=/bin/zsh

COPY --chown=dev:dev config/.zshrc /home/dev/.zshrc

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
