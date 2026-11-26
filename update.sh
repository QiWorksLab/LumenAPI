#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

say(){ printf '%s\n' "$*"; }
die(){ say "✗ $*"; exit 1; }

command -v git >/dev/null 2>&1 || die "未检测到 git"
command -v docker >/dev/null 2>&1 || die "未检测到 docker"
docker compose version >/dev/null 2>&1 || die "未检测到 Docker Compose 插件"

if [[ -n "$(git status --porcelain)" ]]; then
  die "Git 工作区存在未提交改动，已停止更新，避免覆盖本地修改。"
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
OLD_COMMIT="$(git rev-parse HEAD)"
OLD_IMAGE_ID="$(docker image inspect lumenapi:latest --format '{{.Id}}' 2>/dev/null || true)"

say "[1/7] 获取远程更新"
git fetch --prune origin

say "[2/7] 拉取最新代码（仅 fast-forward）"
git pull --ff-only origin "$BRANCH"
NEW_COMMIT="$(git rev-parse HEAD)"

say "[3/7] 校验 Docker Compose"
docker compose config -q
SERVICES="$(docker compose config --services)"
if [[ "$SERVICES" != "lumenapi" ]]; then
  die "检测到 Compose 服务不止 lumenapi，拒绝继续。当前服务：$SERVICES"
fi

if [[ -n "$OLD_IMAGE_ID" ]]; then
  say "[4/7] 保存当前运行镜像为 lumenapi:rollback"
  docker tag "$OLD_IMAGE_ID" lumenapi:rollback
else
  say "[4/7] 当前没有可用旧镜像，跳过 rollback 标签"
fi

say "[5/7] 构建新镜像"
docker compose build

say "[6/7] 重建唯一 lumenapi 容器"
docker compose up -d --remove-orphans

say "[7/7] 等待健康检查"
CONTAINER_ID="$(docker compose ps -q lumenapi)"
[[ -n "$CONTAINER_ID" ]] || die "未找到 lumenapi 容器"
WEB_PORT="$(docker compose port lumenapi 80 2>/dev/null | awk -F: 'END{print $NF}')"
[[ "$WEB_PORT" =~ ^[0-9]+$ ]] || die "无法确定 LumenAPI Web 映射端口"

OK=0
for _ in $(seq 1 40); do
  STATUS="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CONTAINER_ID" 2>/dev/null || true)"
  if [[ "$STATUS" == "healthy" ]]; then
    if curl -fsS --max-time 3 http://127.0.0.1:${WEB_PORT}/healthz 2>/dev/null | grep -qx ok; then
      OK=1
      break
    fi
  fi
  sleep 3
done

if [[ "$OK" == 1 ]]; then
  say "✓ 更新成功"
  say "  代码: $OLD_COMMIT -> $NEW_COMMIT"
  say "  容器: $(docker compose ps --format json lumenapi 2>/dev/null | head -c 300 || true)"
  say "  回滚镜像保留为 lumenapi:rollback"
  exit 0
fi

say "✗ 新版本健康检查失败，开始自动回滚运行镜像"
if docker image inspect lumenapi:rollback >/dev/null 2>&1; then
  docker tag lumenapi:rollback lumenapi:latest
  docker compose up -d --force-recreate --no-build --remove-orphans
  sleep 5
  ROLLBACK_ID="$(docker compose ps -q lumenapi)"
  ROLLBACK_STATUS="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$ROLLBACK_ID" 2>/dev/null || true)"
  say "✓ 已切回上一版镜像，当前状态: $ROLLBACK_STATUS"
  say "! 注意：Git 代码仍保持在新提交 $NEW_COMMIT，没有自动 reset，避免修改仓库历史/工作区。"
  exit 2
fi

die "新版本健康检查失败，且没有可用 rollback 镜像。"
