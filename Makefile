# hdyadmin 独立业务模块构建入口

ENV_FILE := $(firstword $(wildcard .env.local .env))
ifneq (,$(ENV_FILE))
    include $(ENV_FILE)
    export
endif

VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
GOFLAGS ?=
LDFLAGS ?= -X main.version=$(VERSION)
BINARY_NAME ?= hdyadmin-template-admin

CURRENT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Docker 镜像构建与推送规则。
include $(CURRENT_DIR)/docker.mk

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
	run-standalone run-frontend run-frontend-connected test test-cover check clean clean-all

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

api-typescript:
	@cd api && buf generate --template buf.typescript.gen.yaml

# 兼容旧模板的命令名称。
ts: api-typescript

openapi:
	@cd api && buf generate --template buf.openapi.gen.yaml

descriptor:
	@cd api && buf build -o ../app/admin/cmd/server/assets/descriptor.bin

wire:
	@cd app/admin && go run -mod=mod github.com/google/wire/cmd/wire ./cmd/server

api-lint:
	@cd api && buf lint
	@cd api && buf format protos --diff --exit-code

api-format:
	@cd api && buf format protos -w

frontend-install:
	@cd frontend/admin && corepack pnpm install --frozen-lockfile

frontend-build: api-typescript frontend-install
	@cd frontend/admin && corepack pnpm build

embed-frontend: frontend-build
	@find app/admin/cmd/server/assets/frontend-dist -mindepth 1 ! -name .gitkeep -delete
	@cp -R frontend/admin/dist/. app/admin/cmd/server/assets/frontend-dist/

build: gen embed-frontend build-server

build-server:
	@mkdir -p ./bin
	@echo "构建 $(BINARY_NAME)..."
	@go build $(GOFLAGS) -ldflags "$(LDFLAGS)" -o ./bin/$(BINARY_NAME) ./app/admin/cmd/server

# 默认以 standalone 模式启动，不依赖 hdyadmin-lcm 和 hdyadmin-core。
run: run-standalone

run-standalone:
	@MODULE_STANDALONE=1 \
		MODULE_TLS_DISABLED=1 \
		ADMIN_GRPC_ENDPOINT= \
		go run ./app/admin/cmd/server -c ./app/admin/configs

# 完整联调模式：使用 .env.local/.env 连接 LCM 申请证书并注册到 Core。
run-server:
	@go run ./app/admin/cmd/server -c ./app/admin/configs

run-frontend:
	@cd frontend/admin && corepack pnpm dev

run-frontend-connected:
	@cd frontend/admin && corepack pnpm dev:connected

test:
	@go test ./...

test-cover:
	@go test -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "覆盖率报告已生成：coverage.html"

check: api-lint test frontend-build

clean:
	@find bin frontend/admin/dist frontend/admin/.__mf__temp -depth -delete 2>/dev/null || true
	@find app/admin/cmd/server/assets/frontend-dist -mindepth 1 ! -name .gitkeep -delete
	@find coverage.out coverage.html -type f -delete 2>/dev/null || true
	@echo "构建产物已清理（保留 frontend/admin/node_modules）。"

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
