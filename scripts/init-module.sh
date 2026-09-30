#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
用法：
  ./scripts/init-module.sh \
    --id <模块ID> \
    --name <展示名称> \
    --go-module <Go模块路径> \
    [--description <描述>] \
    [--grpc-port <端口>] \
    [--http-port <端口>] \
    [--frontend-port <端口>] \
    [--skip-generate]

示例：
  ./scripts/init-module.sh \
    --id vip \
    --name VIP \
    --go-module github.com/example/hdyadmin-vip \
    --grpc-port 10400 \
    --http-port 10401 \
    --frontend-port 3011
EOF
}

module_id=""
module_name=""
go_module=""
description=""
grpc_port="10400"
http_port="10401"
frontend_port="3011"
skip_generate="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --skip-generate)
      skip_generate="1"
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

if [[ -z "$module_id" || -z "$module_name" || -z "$go_module" ]]; then
  echo "--id、--name 和 --go-module 为必填参数。" >&2
  usage >&2
  exit 2
fi

if [[ ! "$module_id" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "模块 ID 必须以小写字母开头，且只能包含小写字母、数字和连字符。" >&2
  exit 2
fi

if [[ ! "$go_module" =~ ^[A-Za-z0-9._~-]+(/[A-Za-z0-9._~-]+)+$ ]]; then
  echo "Go module 路径格式无效：$go_module" >&2
  exit 2
fi

if [[ "$module_name" == *$'\n'* || "$module_name" == *$'\r'* || "$module_name" == *'"'* || "$module_name" == *'\'* || "$module_name" == *'#'* || "$module_name" == *':'* ]]; then
  echo "模块展示名称不能包含换行、引号、反斜杠、# 或冒号。" >&2
  exit 2
fi

for port in "$grpc_port" "$http_port" "$frontend_port"; do
  if [[ ! "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
    echo "端口必须是 1-65535 的整数：$port" >&2
    exit 2
  fi
done

if [[ "$grpc_port" == "$http_port" || "$grpc_port" == "$frontend_port" || "$http_port" == "$frontend_port" ]]; then
  echo "gRPC、HTTP 和前端端口不能重复。" >&2
  exit 2
fi

if [[ -z "$description" ]]; then
  description="$module_name module for hdyadmin"
fi

if [[ "$description" == *$'\n'* || "$description" == *$'\r'* || "$description" == *'"'* || "$description" == *'\'* || "$description" == *'#'* || "$description" == *':'* ]]; then
  echo "模块描述不能包含换行、引号、反斜杠、# 或冒号。" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
cd "$project_dir"

old_id="tem""plate"
old_name="Tem""plate"
old_repo="hdyadmin-""template"
old_go_module="github.com/neo-fork-gotangra/""hdyadmin-template"
module_env_prefix="$(printf '%s' "$module_id" | tr '[:lower:]-' '[:upper:]_')"

replace_tracked() {
  local old_value="$1"
  local new_value="$2"
  local file

  while IFS= read -r file; do
    [[ -z "$file" || "$file" == "scripts/init-module.sh" ]] && continue
    # protoc-gen-go encodes go_package with a length prefix in raw descriptors.
    # Text replacement would corrupt that descriptor; `make gen` rewrites it safely.
    [[ "$file" == pb/*.pb.go ]] && continue
    OLD_VALUE="$old_value" NEW_VALUE="$new_value" perl -0pi -e \
      's/\Q$ENV{OLD_VALUE}\E/$ENV{NEW_VALUE}/g' "$file"
  done < <(git grep -Il -- "$old_value" || true)
}

replace_tracked "$old_go_module" "$go_module"
replace_tracked "$old_repo" "hdyadmin-$module_id"
replace_tracked "10400" "$grpc_port"
replace_tracked "10401" "$http_port"
replace_tracked "3011" "$frontend_port"

# 模块 ID 只替换明确承载模块元数据的文件，避免改写普通英文说明。
metadata_files=(
  README.md
  app/cmd/server/main.go
  app/cmd/server/assets/menus.yaml
  app/cmd/server/assets/openapi.yaml
  app/internal/security/cert/cert_manager.go
  app/internal/server/grpc.go
  app/internal/server/http.go
  api/buf.openapi.gen.yaml
  frontend/index.html
  frontend/package.json
  frontend/vite.config.ts
  frontend/vite.hotreload.config.ts
  frontend/src/index.ts
  frontend/src/routes.ts
  frontend/src/api/client.ts
  frontend/src/locales/en-US.json
  .env.example
  .vscode/launch.json
  .vscode/tasks.json
)

for file in "${metadata_files[@]}"; do
  OLD_VALUE="$old_id" NEW_VALUE="$module_id" perl -0pi -e \
    's/\Q$ENV{OLD_VALUE}\E/$ENV{NEW_VALUE}/g' "$file"
  OLD_VALUE="$old_name" NEW_VALUE="$module_name" perl -0pi -e \
    's/\Q$ENV{OLD_VALUE}\E/$ENV{NEW_VALUE}/g' "$file"
done

OLD_VALUE="TEMPLATE" NEW_VALUE="$module_env_prefix" perl -0pi -e \
  's/\Q$ENV{OLD_VALUE}\E/$ENV{NEW_VALUE}/g' app/internal/security/cert/cert_manager.go
OLD_VALUE="Starter module for hdyadmin" NEW_VALUE="$description" perl -0pi -e \
  's/\Q$ENV{OLD_VALUE}\E/$ENV{NEW_VALUE}/g' \
  app/cmd/server/main.go app/cmd/server/assets/menus.yaml

go mod edit -module "$go_module"

if [[ "$skip_generate" == "0" ]]; then
  required_tools=(buf protoc-gen-go protoc-gen-go-grpc protoc-gen-go-http protoc-gen-openapi protoc-gen-redact protoc-gen-typescript-http)
  missing_tools=()
  for tool in "${required_tools[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
  done
  if ((${#missing_tools[@]} > 0)); then
    echo "缺少生成工具：${missing_tools[*]}" >&2
    echo "请先运行 make tools，再运行 make gen。模板元数据已完成更新。" >&2
  else
    make gen
  fi
fi

go mod tidy

echo
echo "模块初始化完成："
echo "  ID:       $module_id"
echo "  名称:     $module_name"
echo "  Go module: $go_module"
echo "  gRPC:     $grpc_port"
echo "  HTTP:     $http_port"
echo "  Frontend: $frontend_port"
echo
echo "下一步：复制 .env.example 为 .env.local，填写 hdyadmin 开发环境的注册与证书参数。"
