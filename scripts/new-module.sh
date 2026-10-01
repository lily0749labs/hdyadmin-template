#!/usr/bin/env bash
# HdyAdmin 独立业务模块创建器。
#
# 脚本先把 hdyadmin-template 克隆到临时目录，移除模板的 Git 元数据，
# 再替换模块信息、生成代码并执行校验。
# 只有全部步骤成功后才会把项目移入目标目录；失败时保留临时目录便于排查。

set -euo pipefail

DEFAULT_REPO_URL="https://github.com/neo-fork-gotangra/hdyadmin-template.git"

usage() {
	cat <<'EOF'
用法：
  # 交互式创建（DevKit 菜单使用此方式）
  bash devkit/install_hdyadmin.sh --interactive

  # 参数式创建
  bash devkit/install_hdyadmin.sh \
    --target <目标目录> \
    --id <模块ID> \
    --name <展示名称> \
    --go-module <Go模块路径> \
    [--project-prefix <项目前缀>] \
    [--description <描述>] \
    [--menu-name-en <英文菜单名>] \
    [--menu-name-zh <中文菜单名>] \
    [--grpc-port <端口>] \
    [--http-port <端口>] \
    [--frontend-port <端口>] \
    [--repo-url <模板仓库>] \
    [--branch <模板分支>] \
    [--skip-frontend] \
    [--skip-check] \
    [--interactive]

必填参数：
  --target DIR        新项目目录，必须不存在
  --id ID             模块 ID：小写字母开头，只允许小写字母、数字和连字符
  --name NAME         模块展示名称
  --go-module PATH    Go module 路径，例如 github.com/example/hdyadmin-vip

可选参数：
  --project-prefix PREFIX  项目名前缀（默认 hdyadmin），用于项目、可执行文件和镜像命名
  --description TEXT  模块描述（默认由模板根据展示名生成）
  --menu-name-en TEXT 英文菜单名（默认为“<展示名称> Module”）
  --menu-name-zh TEXT 中文菜单名（默认为“<展示名称>模块”）
  --grpc-port PORT    gRPC 端口（默认 10400）
  --http-port PORT    模块资源 HTTP 端口（默认 10401）
  --frontend-port PORT  前端远程模块端口（默认 3011）
  --repo-url URL      模板 Git 地址（默认为官方 hdyadmin-template）
  --branch NAME       指定模板分支或 tag（默认使用远程默认分支）
  --skip-frontend     跳过前端依赖安装和构建，保留后端检查
  --skip-check        跳过初始化后的 lint、测试及前后端构建
  --interactive       交互填写参数；可与其他参数组合并作为默认值
  -h, --help          显示帮助

示例：
  bash devkit/install_hdyadmin.sh \
    --target ../hdyadmin-vip \
    --id vip \
    --name VIP \
    --project-prefix hdyadmin \
    --go-module github.com/example/hdyadmin-vip

说明：
  默认会执行模板初始化、Proto lint、Go 测试、服务端构建以及前端构建。
  创建后不保留模板的 .git；请在目标目录中按需执行 git init。
EOF
}

fail_usage() {
	echo "❌ $1" >&2
	echo >&2
	usage >&2
	exit 64
}

require_option_value() {
	if (($# < 2)) || [[ -z "${2:-}" || "${2:-}" == --* ]]; then
		fail_usage "$1 缺少参数。"
	fi
}

prompt_value() {
	local label="$1"
	local default_value="$2"
	local required="$3"
	local variable_name="$4"
	local value

	while true; do
		if [[ -n "$default_value" ]]; then
			printf '%s [%s]：' "$label" "$default_value"
		else
			printf '%s：' "$label"
		fi
		if ! IFS= read -r value; then
			echo >&2
			echo "❌ 输入已终止。" >&2
			exit 1
		fi
		[[ -n "$value" ]] || value="$default_value"
		if [[ "$required" == "1" && -z "$value" ]]; then
			echo "❌ $label 不能为空。" >&2
			continue
		fi
		printf -v "$variable_name" '%s' "$value"
		return
	done
}

prompt_yes_no() {
	local label="$1"
	local current_value="$2"
	local variable_name="$3"
	local hint answer

	if [[ "$current_value" == "1" ]]; then
		hint="Y/n"
	else
		hint="y/N"
	fi
	while true; do
		printf '%s [%s]：' "$label" "$hint"
		if ! IFS= read -r answer; then
			echo >&2
			echo "❌ 输入已终止。" >&2
			exit 1
		fi
		case "$answer" in
		"")
			printf -v "$variable_name" '%s' "$current_value"
			return
			;;
		y | Y | yes | YES)
			printf -v "$variable_name" '%s' "1"
			return
			;;
		n | N | no | NO)
			printf -v "$variable_name" '%s' "0"
			return
			;;
		*) echo "❌ 请输入 y 或 n。" >&2 ;;
		esac
	done
}

replace_in_file() {
	local old_value="$1"
	local new_value="$2"
	local file="$3"

	[[ -z "$old_value" || "$old_value" == "$new_value" || ! -f "$file" ]] && return
	OLD_VALUE="$old_value" NEW_VALUE="$new_value" perl -0pi -e \
		's/\Q$ENV{OLD_VALUE}\E/$ENV{NEW_VALUE}/g' "$file"
}

replace_project_text() {
	local old_value="$1"
	local new_value="$2"
	local file relative_file

	[[ -z "$old_value" || "$old_value" == "$new_value" ]] && return

	while IFS= read -r -d '' file; do
		relative_file="${file#./}"
		case "$relative_file" in
		scripts/new-module.sh | scripts/init-module.sh | pb/*.pb.go | api/pb/*.pb.go) continue ;;
		esac
		if LC_ALL=C grep -IFq -- "$old_value" "$file"; then
			replace_in_file "$old_value" "$new_value" "$file"
		fi
	done < <(
		find . \
			\( -type d \( \
				-name .git -o \
				-name node_modules -o \
				-name vendor -o \
				-name dist -o \
				-name .pnpm-store -o \
				-name .cache -o \
				-name .vite \
			\) -prune \) -o \
			-type f -print0
	)
}

initialize_module() {
	local project_dir="$1"
	local old_id="tem""plate"
	local old_name="Tem""plate"
	local old_repo="hdyadmin-""template"
	local module_env_prefix current_go_module file tool
	local -a metadata_files generation_tools missing_tools

	(
		cd "$project_dir"

		if [[ ! -f go.mod ]]; then
			echo "❌ 项目目录中不存在 go.mod：$project_dir" >&2
			exit 1
		fi

		module_env_prefix="$(printf '%s' "$module_id" | tr '[:lower:]-' '[:upper:]_')"
		current_go_module="$(sed -nE 's/^module[[:space:]]+([^[:space:]]+).*$/\1/p' go.mod | head -n 1)"
		if [[ -z "$current_go_module" ]]; then
			echo "❌ 无法从 go.mod 读取当前 Go module。" >&2
			exit 1
		fi

		# 只在 Go 源码和 Buf 配置中替换 module 前缀，避免短 module 名误伤普通路径。
		while IFS= read -r -d '' file; do
			replace_in_file "$current_go_module/" "$go_module/" "$file"
		done < <(
			find app api/tools \
				-type f -name '*.go' \
				! -path '*/vendor/*' \
				-print0 2>/dev/null
		)
		replace_in_file "$current_go_module/" "$go_module/" api/buf.gen.yaml
		replace_in_file "$current_go_module/" "$go_module/" api/buf.openapi.gen.yaml

		replace_project_text "$old_repo" "$project_name"
		replace_project_text "10400" "$grpc_port"
		replace_project_text "10401" "$http_port"
		replace_project_text "3011" "$frontend_port"

		metadata_files=(
			README.md
			app/admin/cmd/server/main.go
			app/admin/cmd/server/assets/menus.yaml
			app/admin/cmd/server/assets/openapi.yaml
			app/admin/internal/security/cert/cert_manager.go
			app/admin/internal/server/grpc.go
			app/admin/internal/server/http.go
			api/buf.openapi.gen.yaml
			frontend/admin/index.html
			frontend/admin/package.json
			frontend/admin/vite.config.ts
			frontend/admin/vite.hotreload.config.ts
			frontend/admin/src/index.ts
			frontend/admin/src/routes.ts
			frontend/admin/src/api/client.ts
			frontend/admin/src/locales/en-US.json
			.env.example
			.vscode/launch.json
			.vscode/tasks.json
		)

		for file in "${metadata_files[@]}"; do
			if [[ ! -f "$file" ]]; then
				echo "❌ 模板缺少元数据文件：$file" >&2
				exit 1
			fi
			replace_in_file "$old_id" "$module_id" "$file"
			replace_in_file "$old_name" "$module_name" "$file"
		done

		replace_in_file "TEMPLATE" "$module_env_prefix" app/admin/internal/security/cert/cert_manager.go
		replace_in_file "Starter module for hdyadmin" "$description" app/admin/cmd/server/main.go
		replace_in_file "Starter module for hdyadmin" "$description" app/admin/cmd/server/assets/menus.yaml
		replace_in_file "Example Module" "$menu_name_en" frontend/admin/src/locales/en-US.json
		replace_in_file "示例模块" "$menu_name_zh" frontend/admin/src/locales/zh-CN.json

		go mod edit -module "$go_module"

		generation_tools=(buf protoc-gen-go protoc-gen-go-grpc protoc-gen-go-http protoc-gen-openapi protoc-gen-redact protoc-gen-typescript-http)
		missing_tools=()
		for tool in "${generation_tools[@]}"; do
			command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
		done
		if ((${#missing_tools[@]} > 0)); then
			echo "⚠️ 缺少生成工具：${missing_tools[*]}" >&2
			echo "模板元数据已更新；请稍后执行 make tools 和 make gen。" >&2
		else
			make gen
		fi

		go mod tidy
	)
}

target=""
module_id=""
module_name=""
go_module=""
project_prefix="hdyadmin"
project_name=""
description=""
menu_name_en=""
menu_name_zh=""
grpc_port="10400"
http_port="10401"
frontend_port="3011"
repo_url="$DEFAULT_REPO_URL"
branch=""
skip_frontend="0"
skip_check="0"
interactive="0"

while (($# > 0)); do
	case "$1" in
	--target)
		require_option_value "$@"
		target="$2"
		shift 2
		;;
	--id)
		require_option_value "$@"
		module_id="$2"
		shift 2
		;;
	--name)
		require_option_value "$@"
		module_name="$2"
		shift 2
		;;
	--go-module)
		require_option_value "$@"
		go_module="$2"
		shift 2
		;;
	--project-prefix)
		require_option_value "$@"
		project_prefix="$2"
		shift 2
		;;
	--description)
		require_option_value "$@"
		description="$2"
		shift 2
		;;
	--menu-name-en)
		require_option_value "$@"
		menu_name_en="$2"
		shift 2
		;;
	--menu-name-zh)
		require_option_value "$@"
		menu_name_zh="$2"
		shift 2
		;;
	--grpc-port)
		require_option_value "$@"
		grpc_port="$2"
		shift 2
		;;
	--http-port)
		require_option_value "$@"
		http_port="$2"
		shift 2
		;;
	--frontend-port)
		require_option_value "$@"
		frontend_port="$2"
		shift 2
		;;
	--repo-url)
		require_option_value "$@"
		repo_url="$2"
		shift 2
		;;
	--branch)
		require_option_value "$@"
		branch="$2"
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
	--interactive)
		interactive="1"
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		fail_usage "未知参数：$1"
		;;
	esac
done

if [[ "$interactive" == "1" ]]; then
	echo "HdyAdmin 独立业务模块交互式创建"
	echo "按回车使用方括号中的默认值。"
	echo
	prompt_value "模块 ID" "$module_id" 1 module_id
	prompt_value "展示名称" "$module_name" 1 module_name
	prompt_value "项目前缀" "$project_prefix" 1 project_prefix
	prompt_value "Go module 路径" "$go_module" 1 go_module
	[[ -n "$target" ]] || target="./$project_prefix-$module_id"
	prompt_value "目标目录" "$target" 1 target
	prompt_value "模块描述（留空使用模板默认值）" "$description" 0 description
	prompt_value "英文菜单名（留空使用模板默认值）" "$menu_name_en" 0 menu_name_en
	prompt_value "中文菜单名（留空使用模板默认值）" "$menu_name_zh" 0 menu_name_zh
	prompt_value "gRPC 端口" "$grpc_port" 1 grpc_port
	prompt_value "HTTP 端口" "$http_port" 1 http_port
	prompt_value "前端端口" "$frontend_port" 1 frontend_port
	prompt_value "模板仓库" "$repo_url" 1 repo_url
	prompt_value "模板分支/tag（留空使用默认分支）" "$branch" 0 branch
	prompt_yes_no "跳过前端安装与构建" "$skip_frontend" skip_frontend
	prompt_yes_no "跳过所有初始化后检查" "$skip_check" skip_check
	echo
fi

if [[ -z "$target" || -z "$module_id" || -z "$module_name" || -z "$go_module" ]]; then
	fail_usage "--target、--id、--name 和 --go-module 为必填参数。"
fi

[[ -n "$description" ]] || description="$module_name module for $project_prefix"
[[ -n "$menu_name_en" ]] || menu_name_en="$module_name Module"
[[ -n "$menu_name_zh" ]] || menu_name_zh="${module_name}模块"

if [[ ! "$module_id" =~ ^[a-z][a-z0-9-]*$ ]]; then
	fail_usage "模块 ID 必须以小写字母开头，且只能包含小写字母、数字和连字符。"
fi
if [[ ! "$project_prefix" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]]; then
	fail_usage "项目前缀必须以小写字母开头，只能包含小写字母、数字和连字符，且连字符不能连续或位于末尾。"
fi
project_name="$project_prefix-$module_id"
if [[ ! "$go_module" =~ ^[A-Za-z0-9._~-]+(/[A-Za-z0-9._~-]+)+$ ]]; then
	fail_usage "Go module 路径格式无效：$go_module"
fi
if [[ "$module_name" == *$'\n'* || "$module_name" == *$'\r'* || "$module_name" == *'"'* || "$module_name" == *'\'* || "$module_name" == *'#'* || "$module_name" == *':'* ]]; then
	fail_usage "模块展示名称不能包含换行、引号、反斜杠、# 或冒号。"
fi
if [[ -n "$description" && ("$description" == *$'\n'* || "$description" == *$'\r'* || "$description" == *'"'* || "$description" == *'\'* || "$description" == *'#'* || "$description" == *':'*) ]]; then
	fail_usage "模块描述不能包含换行、引号、反斜杠、# 或冒号。"
fi
for menu_name in "$menu_name_en" "$menu_name_zh"; do
	if [[ "$menu_name" == *$'\n'* || "$menu_name" == *$'\r'* || "$menu_name" == *'"'* || "$menu_name" == *'\'* ]]; then
		fail_usage "菜单名称不能包含换行、引号或反斜杠。"
	fi
done

for port in "$grpc_port" "$http_port" "$frontend_port"; do
	if [[ ! "$port" =~ ^[0-9]+$ || ${#port} -gt 5 ]] || ((10#$port < 1 || 10#$port > 65535)); then
		fail_usage "端口必须是 1-65535 的整数：$port"
	fi
done
if ((10#$grpc_port == 10#$http_port || 10#$grpc_port == 10#$frontend_port || 10#$http_port == 10#$frontend_port)); then
	fail_usage "gRPC、HTTP 和前端端口不能重复。"
fi

if [[ -e "$target" || -L "$target" ]]; then
	echo "❌ 目标目录已经存在，为避免覆盖已停止：$target" >&2
	exit 1
fi

required_commands=(git go make perl)
if [[ "$skip_check" == "0" ]]; then
	required_commands+=(
		buf
		protoc-gen-go
		protoc-gen-go-grpc
		protoc-gen-go-http
		protoc-gen-openapi
		protoc-gen-redact
		protoc-gen-typescript-http
	)
	if [[ "$skip_frontend" == "0" ]]; then
		required_commands+=(corepack)
	fi
fi

missing_commands=()
for command_name in "${required_commands[@]}"; do
	command -v "$command_name" >/dev/null 2>&1 || missing_commands+=("$command_name")
done
if ((${#missing_commands[@]} > 0)); then
	echo "❌ 缺少所需命令：${missing_commands[*]}" >&2
	if [[ "$skip_check" == "0" ]]; then
		echo "请先按 hdyadmin-template 的 README 安装生成工具和前端环境。" >&2
		echo "如果只需先生成项目骨架，可使用 --skip-check，之后在项目中执行 make tools、make gen 和 make check。" >&2
	fi
	exit 1
fi

script_source="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
target_parent_input="$(dirname "$target")"
mkdir -p "$target_parent_input"
target_parent="$(cd "$target_parent_input" && pwd -P)"
target_dir="$target_parent/$(basename "$target")"

staging_root="$(mktemp -d)"
staged_target="$staging_root/$(basename "$target_dir")"

report_staging_on_error() {
	local status=$?
	if [[ "$status" -ne 0 && -n "$staging_root" && -d "$staging_root" ]]; then
		echo "❌ 创建失败；临时项目已保留用于排查：$staging_root" >&2
	fi
	trap - EXIT
	exit "$status"
}
trap report_staging_on_error EXIT

clone_args=(clone --depth 1)
if [[ -n "$branch" ]]; then
	clone_args+=(--branch "$branch" --single-branch)
fi
clone_args+=("$repo_url" "$staged_target")

echo "📥 获取 HdyAdmin 模板：$repo_url"
echo "🏷️  项目名称：$project_name"
echo "📂 目标目录：$target_dir"
git "${clone_args[@]}"

# 新模块不继承模板仓库的 Git 元数据，后续可按实际远程重新执行 git init。
template_git_dir="$staged_target/.git"
expected_git_dir="$staging_root/$(basename "$target_dir")/.git"
if [[ ! -d "$template_git_dir" || "$template_git_dir" != "$expected_git_dir" ]]; then
	echo "❌ 模板 Git 目录校验失败：$template_git_dir" >&2
	exit 1
fi
find "$template_git_dir" -depth -delete

# 无论模板远程仓库是否已经更新，都让新项目保留当前版本的一键创建入口。
mkdir -p "$staged_target/scripts"
cp "$script_source" "$staged_target/scripts/new-module.sh"
chmod +x "$staged_target/scripts/new-module.sh"

# 兼容仍带旧初始化脚本的模板分支；初始化逻辑现已合并到本脚本。
legacy_init_script="$staged_target/scripts/init-module.sh"
if [[ -e "$legacy_init_script" || -L "$legacy_init_script" ]]; then
	find "$legacy_init_script" -maxdepth 0 -delete
fi

echo "⚙️  初始化模块：$module_id"
initialize_module "$staged_target"

if [[ "$skip_check" == "0" ]]; then
	echo "🧪 执行 Proto lint、Go 测试和服务端构建..."
	make -C "$staged_target" api-lint
	make -C "$staged_target" test
	make -C "$staged_target" build-server

	if [[ "$skip_frontend" == "0" ]]; then
		echo "🎨 安装前端依赖并构建..."
		make -C "$staged_target" frontend-install
		make -C "$staged_target" frontend-build
	fi
else
	echo "⚠️ 已跳过初始化后检查；使用项目前请补充执行 make tools、make gen 和 make check。"
fi

# 克隆和校验期间如果目标路径被其他进程创建，不将项目移入已有目录。
if [[ -e "$target_dir" || -L "$target_dir" ]]; then
	echo "❌ 目标目录在创建过程中已出现，已停止以避免覆盖：$target_dir" >&2
	exit 1
fi

mv "$staged_target" "$target_dir"
rmdir "$staging_root"
staging_root=""
trap - EXIT

echo
echo "✅ HdyAdmin 模块已创建：$target_dir"
echo "下一步："
echo "  cd '$target_dir'"
echo "  cp .env.example .env.local"
echo "  git init"
