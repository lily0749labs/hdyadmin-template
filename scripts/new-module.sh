#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
用法：
  ./scripts/new-module.sh \
    --target <目标目录> \
    --id <模块ID> \
    --name <展示名称> \
    --go-module <Go模块路径> \
    [--description <描述>] \
    [--menu-name-en <英文菜单名>] \
    [--menu-name-zh <中文菜单名>] \
    [--grpc-port <端口>] \
    [--http-port <端口>] \
    [--frontend-port <端口>] \
    [--gohdy-bin <gohdy可执行文件>] \
    [--repo-url <模板仓库>] \
    [--branch <模板分支>] \
    [--timeout <超时>] \
    [--skip-frontend] \
    [--skip-check]

示例：
  ./scripts/new-module.sh \
    --target /path/to/examples/vip \
    --id vip \
    --name VIP \
    --go-module github.com/example/hdyadmin-vip
EOF
}

target=""
module_id=""
module_name=""
go_module=""
description=""
menu_name_en=""
menu_name_zh=""
grpc_port="10400"
http_port="10401"
frontend_port="3011"
gohdy_bin="${GOHDY_BIN:-}"
repo_url=""
branch=""
timeout="5m"
skip_frontend="0"
skip_check="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      target="${2:-}"
      shift 2
      ;;
    --id)
      module_id="${2:-}"
      shift 2
      ;;
    --name)
      module_name="${2:-}"
      shift 2
      ;;
    --go-module)
      go_module="${2:-}"
      shift 2
      ;;
    --description)
      description="${2:-}"
      shift 2
      ;;
    --menu-name-en)
      menu_name_en="${2:-}"
      shift 2
      ;;
    --menu-name-zh)
      menu_name_zh="${2:-}"
      shift 2
      ;;
    --grpc-port)
      grpc_port="${2:-}"
      shift 2
      ;;
    --http-port)
      http_port="${2:-}"
      shift 2
      ;;
    --frontend-port)
      frontend_port="${2:-}"
      shift 2
      ;;
    --gohdy-bin)
      gohdy_bin="${2:-}"
      shift 2
      ;;
    --repo-url)
      repo_url="${2:-}"
      shift 2
      ;;
    --branch)
      branch="${2:-}"
      shift 2
      ;;
    --timeout)
      timeout="${2:-}"
      shift 2
      ;;
    --skip-frontend)
      skip_frontend="1"
      shift
      ;;
    --skip-check)
      skip_check="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$target" || -z "$module_id" || -z "$module_name" || -z "$go_module" ]]; then
  echo "--target、--id、--name 和 --go-module 为必填参数。" >&2
  usage >&2
  exit 2
fi

if [[ -e "$target" ]]; then
  echo "目标目录已经存在，为避免覆盖已停止：$target" >&2
  exit 1
fi

target_parent_input="$(dirname "$target")"
mkdir -p "$target_parent_input"
target_parent="$(cd "$target_parent_input" && pwd)"
target_dir="$target_parent/$(basename "$target")"

if [[ -z "$gohdy_bin" ]]; then
  gohdy_bin="$(command -v gohdy || true)"
fi
if [[ -z "$gohdy_bin" || ! -x "$gohdy_bin" ]]; then
  echo "找不到 gohdy 可执行文件；请设置 GOHDY_BIN 或传入 --gohdy-bin。" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
staging_root="$(mktemp -d)"
staged_target="$staging_root/$(basename "$target_dir")"

report_staging_on_error() {
  local status=$?
  if [[ "$status" -ne 0 && -n "$staging_root" && -d "$staging_root" ]]; then
    echo "创建失败；临时项目已保留用于排查：$staging_root" >&2
  fi
  trap - EXIT
  exit "$status"
}
trap report_staging_on_error EXIT

gohdy_args=(
  # gohdy 当前会扫描目标的父目录；放入独立临时目录可避免影响同级项目。
  new project "$staged_target"
  --module "$go_module"
  --timeout "$timeout"
)
if [[ -n "$repo_url" ]]; then
  gohdy_args+=(--repo-url "$repo_url")
fi
if [[ -n "$branch" ]]; then
  gohdy_args+=(--branch "$branch")
fi

echo "创建项目：$target_dir"
"$gohdy_bin" "${gohdy_args[@]}"

# 使用当前入口脚本配套的初始化脚本，避免 gohdy 模板缓存中仍是旧版本。
cp "$script_dir/init-module.sh" "$staged_target/scripts/init-module.sh"
cp "$script_dir/new-module.sh" "$staged_target/scripts/new-module.sh"
chmod +x "$staged_target/scripts/init-module.sh" "$staged_target/scripts/new-module.sh"

init_args=(
  --project-dir "$staged_target"
  --id "$module_id"
  --name "$module_name"
  --go-module "$go_module"
  --grpc-port "$grpc_port"
  --http-port "$http_port"
  --frontend-port "$frontend_port"
)
if [[ -n "$description" ]]; then
  init_args+=(--description "$description")
fi
if [[ -n "$menu_name_en" ]]; then
  init_args+=(--menu-name-en "$menu_name_en")
fi
if [[ -n "$menu_name_zh" ]]; then
  init_args+=(--menu-name-zh "$menu_name_zh")
fi

"$script_dir/init-module.sh" "${init_args[@]}"

if [[ "$skip_check" == "0" ]]; then
  make -C "$staged_target" api-lint
  make -C "$staged_target" test
  make -C "$staged_target" build-server

  if [[ "$skip_frontend" == "0" ]]; then
    make -C "$staged_target" frontend-install
    make -C "$staged_target" frontend-build
  fi
fi

mv "$staged_target" "$target_dir"
rmdir "$staging_root"
staging_root=""
trap - EXIT

echo
echo "项目已创建并初始化：$target_dir"
