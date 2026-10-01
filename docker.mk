# Docker 镜像构建与推送规则
#
# 本文件由项目根目录的 Makefile 引入，集中管理镜像名称、仓库登录、
# 本地单架构构建和远程多架构发布。通常不需要直接使用 `make -f` 执行本文件。
#
# 常用命令：
#   make docker                         构建当前主机架构镜像并加载到本地 Docker
#   make docker IMG_VERSION=v1.0.0      使用指定版本构建本地镜像
#   make docker-push IMG_VERSION=v1.0.0 构建并推送 amd64、arm64 镜像
#   make docker-buildx DOCKER_OUTPUT=--push 手动执行 Buildx 构建
#
# 所有使用 `?=` 定义的变量都允许通过环境变量、`.env.local`、`.env`
# 或命令行覆盖，例如：
#   make docker TARGET=registry.example.com PRJ=my-project

# -----------------------------------------------------------------------------
# 镜像地址
# -----------------------------------------------------------------------------
# TARGET：镜像仓库域名，不包含 http:// 或 https://。
# PRJ：仓库中的项目或命名空间。
# IMAGE_NAME：镜像名称，默认与服务端可执行文件一致。
# IMG_VERSION：镜像版本，默认继承主 Makefile 中的 VERSION。
# IMAGE_REF：最终镜像地址，不包含标签，例如 registry/project/image。
TARGET      ?= reghub.hdyops.qzz.io
PRJ         ?= hdyadmin
IMAGE_NAME  ?= $(BINARY_NAME)
IMG_VERSION ?= $(VERSION)
IMAGE_REF    = $(TARGET)/$(PRJ)/$(IMAGE_NAME)

# -----------------------------------------------------------------------------
# OCI 镜像元数据
# -----------------------------------------------------------------------------
# 这些值会写入镜像标签，便于在镜像仓库中查询源码、版本、厂商和许可证。
# IMG_SOURCE 默认读取当前 Git 仓库的远程地址。
IMG_SOURCE   ?= $(shell git config --get remote.origin.url 2>/dev/null)
IMG_URL      ?= https://regui.hdyops.qzz.io
IMG_VENDOR   ?= HDY Auto
IMG_LICENSES ?= Apache-2.0
IMG_TITLE    ?= $(BINARY_NAME)

# -----------------------------------------------------------------------------
# Buildx 构建参数
# -----------------------------------------------------------------------------
# DOCKER_PLATFORMS：发布镜像包含的 CPU 架构。
# LOCAL_DOCKER_PLATFORM：`make docker` 使用的当前开发机架构。
# DOCKER_OUTPUT：Buildx 输出方式；--push 推送仓库，--load 加载到本机。
# DOCKER_EXTRA_ARGS：关闭额外的 provenance 和 SBOM 清单，兼容目标镜像仓库。
DOCKER_PLATFORMS      ?= linux/amd64,linux/arm64
LOCAL_DOCKER_PLATFORM ?= linux/$(shell go env GOARCH)
DOCKER_OUTPUT         ?= --push
DOCKER_EXTRA_ARGS     ?= --provenance=false --sbom=false

# -----------------------------------------------------------------------------
# 镜像仓库登录参数
# -----------------------------------------------------------------------------
# Reghub_Login_Url 可以包含协议，供 `docker login` 使用。
# Reghub_Pwd 可以通过环境变量或本地 .env 文件提供；未设置时会在终端安全询问。
# CI 等非交互环境必须显式设置该变量。禁止把真实密码提交到仓库。
# 登录时通过标准输入传递密码，避免密码直接出现在命令参数和终端历史中。
Reghub_Login_Url ?= http://$(TARGET)
Reghub_UserName  ?= admin
Reghub_Pwd       ?=

.PHONY: reghub-login docker docker-tag docker-push docker-buildx

# 登录镜像仓库
# 优先使用 Reghub_Pwd；交互运行且未设置时隐藏输入密码，然后安全登录。
reghub-login:
	@password="$${Reghub_Pwd:-}"; \
	if test -z "$$password"; then \
		if ! test -t 0; then \
			echo "错误：非交互环境未设置 Reghub_Pwd，请通过环境变量或本地 .env 文件提供仓库密码。"; \
			exit 1; \
		fi; \
		printf "请输入镜像仓库用户 $(Reghub_UserName) 的密码："; \
		old_stty="$$(stty -g)"; \
		trap 'stty "$$old_stty"' 0 1 2 15; \
		stty -echo; \
		IFS= read -r password; \
		read_status=$$?; \
		stty "$$old_stty"; \
		trap - 0 1 2 15; \
		printf '\n'; \
		if test $$read_status -ne 0 || test -z "$$password"; then \
			echo "错误：未输入仓库密码。"; \
			exit 1; \
		fi; \
	fi; \
	echo "🔑 登录到 Docker 仓库：$(Reghub_Login_Url)"; \
	printf '%s' "$$password" | docker login "$(Reghub_Login_Url)" -u "$(Reghub_UserName)" --password-stdin

# 构建当前主机架构的本地镜像，不推送仓库。
docker:
	@$(MAKE) docker-buildx \
		DOCKER_PLATFORMS="$(LOCAL_DOCKER_PLATFORM)" \
		DOCKER_OUTPUT="--load"

# 兼容旧命令：镜像构建时已直接使用完整仓库标签。
docker-tag: docker
	@echo "镜像已标记：$(IMAGE_REF):$(IMG_VERSION)"

# 登录仓库并构建、推送多架构镜像。
docker-push: reghub-login
	@$(MAKE) docker-buildx DOCKER_OUTPUT="--push"

# Buildx 底层构建目标，负责注入 OCI 元数据、应用版本和两个镜像标签。
docker-buildx:
	@description="$$(git log -1 --pretty=%B 2>/dev/null | tr '\n' ' ' | sed 's/"/\\"/g')"; \
	if test -z "$$description"; then description="$(IMG_TITLE)"; fi; \
	revision="$$(git rev-parse HEAD 2>/dev/null || printf unknown)"; \
	echo "🔧 构建镜像：$(IMAGE_REF):$(IMG_VERSION)"; \
	echo "   平台：$(DOCKER_PLATFORMS)"; \
	docker buildx build \
		--platform "$(DOCKER_PLATFORMS)" \
		$(DOCKER_OUTPUT) \
		$(DOCKER_EXTRA_ARGS) \
		--label "org.opencontainers.image.title=$(IMG_TITLE)" \
		--label "org.opencontainers.image.version=$(IMG_VERSION)" \
		--label "org.opencontainers.image.description=$$description" \
		--label "org.opencontainers.image.created=$$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
		--label "org.opencontainers.image.source=$(IMG_SOURCE)" \
		--label "org.opencontainers.image.revision=$$revision" \
		--label "org.opencontainers.image.url=$(IMG_URL)" \
		--label "org.opencontainers.image.vendor=$(IMG_VENDOR)" \
		--label "org.opencontainers.image.licenses=$(IMG_LICENSES)" \
		-t "$(IMAGE_REF):$(IMG_VERSION)" \
		-t "$(IMAGE_REF):latest" \
		--build-arg APP_VERSION="$(IMG_VERSION)" \
		-f Dockerfile .
