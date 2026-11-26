# LumenAPI

LumenAPI 的全新初始化 Docker 版本（公开源码仓库）。

## 特点
- GitHub Actions 构建 Linux AMD64 镜像并发布 GHCR。
- 不包含服务器的生产 .env、密钥、数据库记录或运行时数据。
- 通过独立 MySQL 数据库、Redis 和持久化数据卷完成首次安装。

## 部署
1. 准备全新的 MySQL 数据库及用户，避免连接现有生产数据库。
2. 复制 `.env.example` 为 `.env`，填写数据库和运行参数。
3. 在宿主机安全目录准备 `integrity.key`、`settings.key`，并按 `compose.yaml` 设置 `LUMEN_SECRETS_DIR`；不可复用其他环境的私钥。
4. 执行 `docker compose pull && docker compose up -d`。
5. 通过健康检查和初始化页面验证部署。

镜像：`ghcr.io/agent-qingjiu/lumenapi:latest`。默认 Web 端口由 `LUMEN_WEB_PORT` 指定（默认 18080，本地回环地址）。

## 数据
MySQL 数据不包含在 Docker 镜像内。Redis、安装标记、会话和日志使用 volumes。不要删除正在使用的数据卷。

## 构建
推送至 main 或手动运行 GitHub Actions 工作流即可构建并推送镜像。
