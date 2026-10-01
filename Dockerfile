##################################
# Stage 0: Generate TypeScript API client
##################################

FROM golang:1.25-alpine AS ts-codegen

ARG BUF_VERSION=1.72.0
ARG TYPESCRIPT_HTTP_VERSION=v0.0.0-20260525125049-694cf6cd0529

RUN apk add --no-cache curl git && \
    curl -sSL "https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}/buf-$(uname -s)-$(uname -m)" -o /usr/local/bin/buf && \
    chmod +x /usr/local/bin/buf && \
    go install github.com/go-kratos/protoc-gen-typescript-http@${TYPESCRIPT_HTTP_VERSION}

WORKDIR /src/api
COPY api/buf.typescript.gen.yaml api/buf.yaml api/buf.lock ./
COPY api/protos/ protos/
RUN buf generate --template buf.typescript.gen.yaml

##################################
# Stage 1: Build frontend remote module
##################################

FROM node:20-alpine AS frontend-builder

RUN corepack enable && corepack prepare pnpm@9 --activate

WORKDIR /frontend
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY frontend/ ./
COPY --from=ts-codegen /src/frontend/src/generated/ src/generated/
RUN pnpm build

##################################
# Stage 2: Build Go executable
##################################

FROM golang:1.25-alpine AS builder

ARG APP_VERSION=1.0.0
ARG TARGETOS=linux
ARG TARGETARCH=amd64

ENV GOTOOLCHAIN=auto

RUN apk add --no-cache git

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=frontend-builder /frontend/dist app/admin/cmd/server/assets/frontend-dist/

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags "-X main.version=${APP_VERSION} -s -w" \
    -o /src/bin/module-server \
    ./app/admin/cmd/server

##################################
# Stage 3: Runtime image
##################################

FROM alpine:3.22

ARG APP_VERSION=1.0.0

RUN apk --no-cache add ca-certificates tzdata

ENV TZ=UTC
WORKDIR /app

COPY --from=builder /src/bin/module-server /app/bin/module-server
COPY --from=builder /src/app/admin/configs/ /app/configs/

RUN addgroup -g 1000 module && \
    adduser -D -u 1000 -G module module && \
    mkdir -p /app/certs && chown -R module:module /app

USER module:module

EXPOSE 10400 10401

CMD ["/app/bin/module-server", "-c", "/app/configs"]

LABEL org.opencontainers.image.title="hdyadmin-template" \
    org.opencontainers.image.description="hdyadmin pluggable business module" \
    org.opencontainers.image.version="${APP_VERSION}"
