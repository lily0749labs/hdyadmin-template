##################################
# 阶段 0：根据 Proto 生成 TypeScript API 客户端
##################################

FROM golang:1.25-alpine AS ts-codegen

ARG BUF_VERSION=1.72.0
ARG TYPESCRIPT_HTTP_VERSION=latest

# 安装 Buf 与 TypeScript HTTP 插件；此阶段只负责协议代码生成。
RUN apk add --no-cache curl git && \
    curl -sSL "https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}/buf-$(uname -s)-$(uname -m)" -o /usr/local/bin/buf && \
    chmod +x /usr/local/bin/buf && \
    go install github.com/go-kratos/protoc-gen-typescript-http@${TYPESCRIPT_HTTP_VERSION}

WORKDIR /src/api
# 先复制生成配置与 Proto 源文件，以充分利用 Docker 分层缓存。
COPY api/buf.typescript.gen.yaml api/buf.yaml api/buf.lock ./
COPY api/protos/ protos/
RUN buf generate --template buf.typescript.gen.yaml

##################################
# 阶段 1：构建 Module Federation 远程前端
##################################

FROM node:20-alpine AS frontend-builder

RUN corepack enable && corepack prepare pnpm@9 --activate

WORKDIR /frontend/admin
# 先安装锁定版本的依赖，再复制源码，避免普通源码改动导致依赖层失效。
COPY frontend/admin/package.json frontend/admin/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY frontend/admin/ ./
# 使用上一阶段新生成的客户端覆盖仓库中的已提交副本，确保与 Proto 一致。
COPY --from=ts-codegen /src/frontend/admin/src/generated/ src/generated/
RUN pnpm build

##################################
# 阶段 2：编译静态 Go 可执行文件并嵌入前端产物
##################################

FROM golang:1.25-alpine AS builder

ARG APP_VERSION=1.0.0
ARG TARGETOS=linux
ARG TARGETARCH

ENV GOTOOLCHAIN=auto

RUN apk add --no-cache git

WORKDIR /src
# 单独下载 Go 依赖，提高源码变更后的缓存命中率。
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# 前端构建结果复制到 go:embed 目录，随服务端二进制一起发布。
COPY --from=frontend-builder /frontend/admin/dist app/admin/cmd/server/assets/frontend-dist/

# 关闭 CGO 以生成便于在精简运行镜像中执行的静态二进制。
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags "-X main.version=${APP_VERSION} -s -w" \
    -o /src/bin/hdyadmin-template-admin \
    ./app/admin/cmd/server

##################################
# 阶段 3：组装最小运行时镜像
##################################

FROM alpine:3.24

ARG APP_VERSION=1.0.0

RUN apk --no-cache add ca-certificates tzdata

ENV TZ=UTC
WORKDIR /app

# 运行镜像只包含可执行文件和默认配置，不携带源码或构建工具链。
COPY --from=builder /src/bin/hdyadmin-template-admin /app/bin/hdyadmin-template-admin
COPY --from=builder /src/app/admin/configs/ /app/configs/

# 创建非 root 用户，并授予证书目录写权限以支持启动时申请或更新证书。
RUN addgroup -g 1000 module && \
    adduser -D -u 1000 -G module module && \
    mkdir -p /app/certs && chown -R module:module /app

USER module:module

# 10400 为 gRPC，10401 为健康检查、注册资源和可选 standalone HTTP API。
EXPOSE 10400 10401

CMD ["/app/bin/hdyadmin-template-admin", "-c", "/app/configs"]

LABEL org.opencontainers.image.title="hdyadmin-template-admin" \
    org.opencontainers.image.description="hdyadmin-template pluggable business module" \
    org.opencontainers.image.version="${APP_VERSION}"
