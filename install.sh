#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"
SECRET_DIR="${LUMEN_INSTALL_SECRET_DIR:-/etc/lumenapi}"
c0='\033[0m'; cg='\033[32m'; cy='\033[33m'; cc='\033[36m'; cr='\033[31m'
say(){ printf "%b\n" "$*"; }
die(){ say "${cr}✗ $*${c0}"; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "缺少 $1，请先安装后重试。"; }
ask_required(){ local v; read -r -p "$1: " v; [[ -n "$v" ]] || die "$1不能为空"; printf -v "$2" '%s' "$v"; }
ask_default(){ local v; read -r -p "$1 [$3]: " v; printf -v "$2" '%s' "${v:-$3}"; }
ask_secret(){ local v; read -r -s -p "$1: " v; echo; [[ -n "$v" ]] || die "$1不能为空"; printf -v "$2" '%s' "$v"; }
dotenv(){ local v=${1//\\/\\\\}; v=${v//\'/\\\'}; printf "'%s'" "$v"; }
rand(){ openssl rand -hex "$1"; }

cat <<'BANNER'
╔══════════════════════════════════════╗
║          LumenAPI Installer          ║
║      Single Container Deployment     ║
╚══════════════════════════════════════╝
BANNER
[[ "$(id -u)" -eq 0 ]] || die "请使用 root 运行安装向导。"
need docker; need openssl; need curl
docker compose version >/dev/null 2>&1 || die "未检测到 Docker Compose 插件。"
if [[ -f "$ENV_FILE" ]]; then
  say "${cy}检测到已有 .env。为防止覆盖现有实例，首次安装已停止。${c0}"
  exit 2
fi

say "\n${cc}[1/5] 宿主机 MySQL${c0}"
say "LumenAPI 不创建 Docker MySQL 容器。MySQL 使用宿主机或你指定的外部实例。"
ask_required "数据库名" DB_NAME
[[ "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]] || die "数据库名仅允许字母、数字和下划线"
ask_required "数据库用户名" DB_USER
ask_secret "数据库密码" DB_PASS
ask_default "MySQL 地址（同机直接回车）" DB_INPUT_HOST "127.0.0.1"
case "$DB_INPUT_HOST" in 127.0.0.1|localhost|::1) DB_HOST="host.docker.internal";; *) DB_HOST="$DB_INPUT_HOST";; esac
ask_default "MySQL 端口" DB_PORT "3306"
[[ "$DB_PORT" =~ ^[0-9]+$ ]] && ((DB_PORT>=1 && DB_PORT<=65535)) || die "MySQL 端口不合法"

say "\n${cc}[2/5] 内置 Redis${c0}"
say "Redis 运行在 LumenAPI 主容器内部，不创建独立 Redis 容器。"
REDIS_INTERNAL=1
REDIS_HOST="127.0.0.1"
REDIS_PORT=6379
REDIS_DATABASE=0
ask_secret "Redis 密码" REDIS_PASSWORD

say "\n${cc}[3/5] 安全配置${c0}"
install -d -m 700 "$SECRET_DIR"
for key in integrity.key settings.key; do
  if [[ ! -s "$SECRET_DIR/$key" ]]; then rand 32 > "$SECRET_DIR/$key"; fi
  chown 0:33 "$SECRET_DIR/$key"; chmod 640 "$SECRET_DIR/$key"
done
say "${cg}✓ Secret 已准备，已有 Key 不会覆盖${c0}"

umask 077
{
  echo "APP_DEBUG=false"; echo "DEFAULT_LANG=zh-cn"; echo
  echo "DB_TYPE=mysql"
  printf 'DB_HOST=%s\n' "$(dotenv "$DB_HOST")"
  printf 'DB_NAME=%s\n' "$(dotenv "$DB_NAME")"
  printf 'DB_USER=%s\n' "$(dotenv "$DB_USER")"
  printf 'DB_PASS=%s\n' "$(dotenv "$DB_PASS")"
  echo "DB_PORT=$DB_PORT"; echo "DB_CHARSET=utf8mb4"; echo "DB_PREFIX=api_"; echo
  echo "REDIS_INTERNAL=1"
  echo "REDIS_HOST='127.0.0.1'"
  echo "REDIS_PORT=6379"
  printf 'REDIS_PASSWORD=%s\n' "$(dotenv "$REDIS_PASSWORD")"
  echo "REDIS_DATABASE=0"; echo
  echo "LUMEN_WEB_PORT=18080"
  printf 'LUMEN_SECRETS_DIR=%s\n' "$(dotenv "$SECRET_DIR")"
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"
say "${cg}✓ MySQL / Redis 配置已持久化到 .env（600）${c0}"

say "\n${cc}[4/5] 构建并启动单容器${c0}"
cd "$ROOT_DIR"
docker compose config -q || die "Compose 配置校验失败"
[[ "$(docker compose config --services | wc -l)" -eq 1 ]] || die "Compose 服务数不是 1，拒绝部署。"
[[ "$(docker compose config --services)" == "lumenapi" ]] || die "Compose 中出现了非 lumenapi 服务，拒绝部署。"
docker compose up -d --build

say "${cc}正在校验目标数据库……${c0}"
DB_READY=0
for _ in $(seq 1 30); do
  set +e
  DB_CHECK_OUTPUT="$(docker compose exec -T -e LUMEN_INSTALL_CREATE_DB=1 lumenapi php scripts/install_database_check.php 2>&1)"
  DB_CHECK_RC=$?
  set -e
  case "$DB_CHECK_RC" in
    0) say "${cg}✓ $DB_CHECK_OUTPUT${c0}"; DB_READY=1; break ;;
    10) sleep 2 ;;
    20) die "目标数据库不是空库。为保护已有数据，LumenAPI 不会复用、覆盖或清空它。请换一个空数据库名。" ;;
    21) die "目标数据库不存在且当前账号无法创建它。请授予 CREATE DATABASE 权限，或先创建空数据库后重试。" ;;
    *) sleep 2 ;;
  esac
done
[[ "$DB_READY" == 1 ]] || die "MySQL 连接在 60 秒内未就绪，请检查宿主机 MySQL 地址、端口、账号密码及访问权限。"

say "\n${cc}[5/5] 健康检查${c0}"
for _ in $(seq 1 20); do
  if curl -fsS --max-time 3 http://127.0.0.1:18080/healthz 2>/dev/null | grep -qx ok; then WEB_OK=1; break; fi
  sleep 2
done
docker compose ps
[[ "${WEB_OK:-0}" == 1 ]] && say "${cg}✓ LumenAPI 健康检查通过${c0}" || say "${cy}! Web 尚未就绪，请执行 docker compose logs --tail=100 lumenapi${c0}"
say "${cg}✓ Docker 只运行 1 个 lumenapi 容器；Redis 已内置；MySQL 使用宿主机/外部实例。${c0}"
say "\n${cg}🎉 部署完成${c0}"
say "本机入口：http://127.0.0.1:18080"
say "首次打开 /install：空数据库将初始化 LumenAPI 全部表，并由你创建第一个 Owner 管理员。"
say "若目标数据库非空，安装器会停止，不会清空或覆盖已有数据。"
say "公网访问请反向代理到 127.0.0.1:18080。"
