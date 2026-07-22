# vLLM CPU One-Click Install

一键安装 vLLM CPU 开发/推理环境（裸机，无需 Docker）。

## 支持系统

- Ubuntu 22.04 (x86-64, AVX2+)
- Ubuntu 24.04 (x86-64, AVX2+)

## 使用

```bash
git clone https://github.com/KASW-UI/vllm-infra.git
cd vllm-infra/vllm-script
bash install.sh
```

等待 10-20 分钟（首次编译 vLLM）。

## 安装内容

| 组件 | 说明 |
|------|------|
| Python 3.12 | venv 隔离环境 |
| PyTorch 2.11.0+cpu | CPU 版本 |
| vLLM | 源码编译，CPU only |
| opencode | bundle/ 内置二进制，零网络 |
| gcc-13 | 自动 PPA / 系统默认 |
| 编译工具 | cmake, ninja, make |
| 系统库 | libnuma, tcmalloc, ffmpeg |
| dev 工具 | vim, tmux, htop, ripgrep, fzf, zsh |

## 高级选项

```bash
VLLM_SRC=/opt/vllm VLLM_REF=v0.6.3 bash install.sh  # 指定路径和版本
VENV_DIR=/opt/vllm-venv bash install.sh                # 指定 venv 路径
```

## 安装后

```bash
source ~/.zshrc
verify     # 验证环境
serve      # 启动 vLLM API server (port 8000)
bench      # 运行 benchmark
snapshot   # 生成环境快照
```

## 目录

```
~/
├── workspace/vllm/          # vLLM 源码
├── workspace/vllm-venv/     # Python venv
├── .config/
│   ├── cpu-vllm-infra/       # 环境配置 + 脚本
│   └── opencode/             # opencode skills + config
└── .local/bin/opencode       # opencode 二进制
```
