# cpu-vllm-infra

vLLM CPU 推理开发环境，Docker 化，可复现。

## 架构

```
cpu-vllm-infra/
├── docker/              # Dockerfile + entrypoint
├── env/                 # 版本锁定 + Python 依赖
├── configs/             # 运行时环境变量
├── scripts/             # 运维脚本
├── deploy/docker/       # docker-compose
├── src/                 # 用户代码挂载点
└── runtime/             # 日志和快照（gitignore）
```

## 快速开始

```bash
make build      # 构建镜像
make run        # 启动容器
make shell      # 进入容器
make verify     # 验证环境
make serve      # 启动 vLLM API 服务
make bench      # 运行 benchmark
make stop       # 停止容器
make clean      # 清理一切
```

## 环境检查

```bash
make verify      # 基础验证
make healthcheck # 完整健康检查
make snapshot    # 生成部署快照
```

## 依赖管理

```bash
make lock        # 更新 requirements.lock
```

## 版本

编辑 `env/versions.env` 修改整个技术栈版本，重新 `make build` 即可。

## 硬件要求

| 架构 | 最低 ISA | 推荐 ISA |
|------|---------|----------|
| x86_64 (Intel) | AVX2 | AVX-512 |
| x86_64 (AMD) | Zen 4+ (AVX-512) | AVX-512 + zentorch |
| ARM AArch64 | NEON | NEON + BFMMLA |
