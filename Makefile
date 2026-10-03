# hdyadmin 独立业务模块构建入口

# 优先加载仅供本机使用的 .env.local，其次加载 .env，并导出给所有子命令。
ENV_FILE := $(firstword $(wildcard .env.local .env))
ifneq (,$(ENV_FILE))
    include $(ENV_FILE)
    export
endif

# 构建元数据；均可通过环境变量或 make 命令行参数覆盖。
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
GOFLAGS ?=
LDFLAGS ?= -X main.version=$(VERSION)
BINARY_NAME ?= hdyadmin-template-admin

CURRENT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Docker 镜像构建与推送规则。
include $(CURRENT_DIR)/docker.mk

# 代码生成工具版本。除 TypeScript 插件外均固定版本，保证生成结果可复现。
BUF_VERSION ?= v1.72.0
PROTOBUF_VERSION ?= v1.36.12
GRPC_GO_VERSION ?= v1.6.2
KRATOS_TOOL_VERSION ?= v2.0.0-20260404020628-f149714c1d54
GNOSTIC_VERSION ?= v0.7.1
WIRE_VERSION ?= v0.7.0
REDACT_VERSION ?= v3.0.0-20260213125431-7688a38967d4
TYPESCRIPT_HTTP_VERSION ?= latest

.PHONY: help tools gen api api-typescript ts openapi descriptor wire api-lint api-format \
	frontend-install frontend-build embed-frontend build build-server run run-server \
	run-standalone run-frontend run-frontend-connected prepare-env check-connected-env \
	test test-cover check clean clean-all

.NOTPARALLEL: gen build

# 安装代码生成工具。版本固定，避免不同开发机生成结果漂移。
tools:
	@go install github.com/bufbuild/buf/cmd/buf@$(BUF_VERSION)
	@go install google.golang.org/protobuf/cmd/protoc-gen-go@$(PROTOBUF_VERSION)
	@go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@$(GRPC_GO_VERSION)
	@go install github.com/go-kratos/kratos/cmd/protoc-gen-go-http/v2@$(KRATOS_TOOL_VERSION)
	@go install github.com/google/gnostic/cmd/protoc-gen-openapi@$(GNOSTIC_VERSION)
	@go install github.com/menta2k/protoc-gen-redact/v3@$(REDACT_VERSION)
	@go install github.com/go-kratos/protoc-gen-typescript-http@$(TYPESCRIPT_HTTP_VERSION)
	@go install github.com/google/wire/cmd/wire@$(WIRE_VERSION)

# 生成服务端、前端协议代码及所有模块注册资产。
gen: api api-typescript openapi descriptor wire
	@echo "生成完成。"

api:
	@cd api && buf generate --template buf.gen.yaml

# 生成前端调用接口所需的 TypeScript 客户端。
api-typescript:
	@cd api && buf generate --template buf.typescript.gen.yaml

# 兼容旧模板的命令名称。
ts: api-typescript

openapi:
	@cd api && buf generate --template buf.openapi.gen.yaml

# 生成供 Core 动态发现 gRPC 服务使用的 Proto 描述符集合。
descriptor:
	@cd api && buf build -o ../app/admin/cmd/server/assets/descriptor.bin

wire:
	@cd app/admin && go run -mod=mod github.com/google/wire/cmd/wire ./cmd/server

# 同时检查 Buf 规范和 Proto 格式，不自动修改文件。
api-lint:
	@cd api && buf lint
	@cd api && buf format protos --diff --exit-code

api-format:
	@cd api && buf format protos -w

# 按锁文件安装前端依赖；锁文件不一致时立即失败。
frontend-install:
	@cd frontend/admin && corepack pnpm install --frozen-lockfile

frontend-build: api-typescript frontend-install
	@cd frontend/admin && corepack pnpm build

# 将前端产物复制到 Go 嵌入目录，同时保留用于提交空目录的 .gitkeep。
embed-frontend: frontend-build
	@find app/admin/cmd/server/assets/frontend-dist -mindepth 1 ! -name .gitkeep -delete
	@cp -R frontend/admin/dist/. app/admin/cmd/server/assets/frontend-dist/

build: gen embed-frontend build-server

build-server:
	@mkdir -p ./bin
	@echo "构建 $(BINARY_NAME)..."
	@go build $(GOFLAGS) -ldflags "$(LDFLAGS)" -o ./bin/$(BINARY_NAME) ./app/admin/cmd/server

# 首次联调时创建本地环境文件；已有配置绝不覆盖。
prepare-env:
	@if test -f .env.local; then \
		echo ".env.local 已存在，保持原配置。"; \
	else \
		cp .env.example .env.local; \
		echo "已从 .env.example 创建 .env.local，请填写实际的 LCM/Core 地址与凭据。"; \
	fi

# connected 模式依赖真实的 LCM/Core 配置，启动调试器前先拦截空值和示例占位值。
check-connected-env: prepare-env
	@status=0; \
	for key in LCM_BOOTSTRAP_ENDPOINT MODULE_BOOTSTRAP_SECRET LCM_CA_FINGERPRINT ADMIN_GRPC_ENDPOINT; do \
		value="$$(awk -F= -v key="$$key" '$$1 == key { sub(/^[^=]*=/, ""); print; exit }' .env.local)"; \
		case "$$value" in \
			""|replace-with-*) echo "错误：.env.local 中的 $$key 尚未配置。"; status=1 ;; \
		esac; \
	done; \
	fingerprint="$$(awk -F= '$$1 == "LCM_CA_FINGERPRINT" { sub(/^[^=]*=/, ""); print; exit }' .env.local)"; \
	case "$$fingerprint" in \
		""|replace-with-*) ;; \
		*) if ! printf '%s' "$$fingerprint" | grep -Eq '^[0-9A-Fa-f]{64}$$'; then \
			echo "错误：LCM_CA_FINGERPRINT 必须是 64 位 SHA-256 十六进制指纹。"; status=1; \
		fi ;; \
	esac; \
	if test $$status -ne 0; then \
		echo "请填写真实配置；如果本机未运行 LCM/Core，请选择 standalone 调试配置。"; \
		exit $$status; \
	fi; \
	echo "connected 环境变量检查通过。"

# 默认以 standalone 模式启动，不依赖 hdyadmin-lcm 和 hdyadmin-core。
run: run-standalone

run-standalone:
	@MODULE_STANDALONE=1 \
		MODULE_TLS_DISABLED=1 \
		ADMIN_GRPC_ENDPOINT= \
		go run ./app/admin/cmd/server -c ./app/admin/configs

# 完整联调模式：使用 .env.local/.env 连接 LCM 申请证书并注册到 Core。
run-server: check-connected-env
	@go run ./app/admin/cmd/server -c ./app/admin/configs

run-frontend:
	@cd frontend/admin && corepack pnpm dev

run-frontend-connected:
	@cd frontend/admin && corepack pnpm dev:connected

# 运行仓库内全部 Go 测试。
test:
	@go test ./...

test-cover:
	@go test -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "覆盖率报告已生成：coverage.html"

# CI 前的聚合检查：协议规范、Go 测试和前端构建。
check: api-lint test frontend-build

# 清理可重新生成的构建产物，但保留前端依赖以便继续开发。
clean:
	@find bin frontend/admin/dist frontend/admin/.__mf__temp -depth -delete 2>/dev/null || true
	@find app/admin/cmd/server/assets/frontend-dist -mindepth 1 ! -name .gitkeep -delete
	@find coverage.out coverage.html -type f -delete 2>/dev/null || true
	@echo "构建产物已清理（保留 frontend/admin/node_modules）。"

# 在 clean 基础上继续删除前端依赖和项目内 pnpm 缓存。
clean-all: clean
	@find frontend/admin/node_modules .pnpm-store frontend/admin/.pnpm-store -depth -delete 2>/dev/null || true
	@echo "前端依赖和项目内 pnpm 缓存已清理。"

help:
	@echo "hdyadmin-template 可用目标："
	@echo "  make tools             安装固定版本的生成工具"
	@echo "  make gen               生成 Go/TypeScript API、OpenAPI、Descriptor 和 Wire"
	@echo "  make api               生成 Go Protobuf 代码到 api/pb/"
	@echo "  make api-typescript    生成前端 TypeScript API 客户端"
	@echo "  make openapi           生成 OpenAPI 文档"
	@echo "  make descriptor        生成 Proto 描述文件"
	@echo "  make api-lint          检查 Proto 协议及格式"
	@echo "  make prepare-env       缺失时从示例创建 .env.local（不覆盖已有配置）"
	@echo "  make check-connected-env  检查 connected 调试所需的 LCM/Core 配置"
	@echo "  make run               独立启动后端，不连接 LCM/Core"
	@echo "  make run-server        联调启动后端，连接 LCM/Core"
	@echo "  make run-frontend      启动可独立访问的前端调试页"
	@echo "  make run-frontend-connected  启动连接宿主 Shell 的远程前端"
	@echo "  make check             运行协议、Go 和前端检查"
	@echo "  make build             构建完整模块"
	@echo "  make clean             清理构建产物，保留前端依赖"
	@echo "  make clean-all         清理构建产物、前端依赖和项目内缓存"
	@echo "  make docker            构建当前架构镜像并加载到本地 Docker"
	@echo "  make docker-push       构建并推送 amd64、arm64 镜像"

.DEFAULT_GOAL := help
