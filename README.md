# hdyadmin 模块模板

这是用于快速创建 hdyadmin 独立业务模块的模板，包含可接入 `hdyadmin-core` 的
Go/Kratos 后端和 Vue 远程模块。

模板提供一条可验证的最小链路：

- Proto 同时生成 Go、TypeScript、OpenAPI 和 Descriptor。
- 后端启动后向 `hdyadmin-core` 注册模块、接口、菜单和前端入口。
- gRPC 支持通过 `hdyadmin-lcm` 引导 mTLS 证书。
- 前端通过 Module Federation 被 `hdyadmin-frontend` 动态加载。
- 示例接口可验证 Core 的动态 HTTP/gRPC 代理是否可用。

## 环境准备

安装生成工具：

```bash
make tools
```

生成全部代码和注册资产：

```bash
make gen
```

首次安装前端依赖：

```bash
make frontend-install
```

## 本地联调

复制并填写环境变量：

```bash
cp .env.example .env.local
```

需要与 `hdyadmin` 开发环境保持一致的变量包括：

- `LCM_BOOTSTRAP_ENDPOINT`
- `MODULE_BOOTSTRAP_SECRET`
- `LCM_CA_FINGERPRINT`
- `ADMIN_GRPC_ENDPOINT`

不连接 LCM、Core 和宿主 Shell 时，可以启动完整的 standalone 调试链路：

```bash
make run
make run-frontend
```

浏览器访问 `http://localhost:3011`。此模式关闭模块 mTLS、跳过 Core 注册，并由 Vite 将
`/api` 请求代理到模块的 `10401` HTTP 端口，仅用于本地开发和冒烟测试。

联调完整环境时，先确保 `.env.local` 中的 LCM/Core 地址和凭据正确，再分别启动后端和远程前端：

```bash
make run-server
make run-frontend-connected
```

VS Code 的 `Debug template standalone (backend + frontend)` 会启动前后端、等待 Vite 就绪，
然后打开可断点调试的浏览器。Connected 配置会打开宿主页面，并要求 LCM、Core 和宿主 Shell
已经运行。

默认地址：

| 服务 | 地址 |
| --- | --- |
| gRPC | `localhost:10400` |
| 模块资源 HTTP | `http://localhost:10401` |
| 前端远程入口 | `http://localhost:3011/remoteEntry.js` |
| 宿主前端 | `http://localhost:5666` |

模块注册成功后，可通过 Core 代理访问示例接口：

```text
GET /admin/v1/modules/template/v1/examples/Codex
```

## 常用命令

```text
make gen               生成所有代码和注册资产
make api               生成 Go Protobuf 代码
make api-typescript    生成 TypeScript API 客户端
make openapi           生成 OpenAPI 文档
make descriptor        生成 Proto descriptor
make wire              生成依赖注入代码
make api-lint          检查 Proto
make test              运行 Go 测试
make run               standalone 模式启动后端
make run-server        连接 LCM/Core 启动后端
make run-frontend      启动 standalone 前端调试页
make run-frontend-connected  启动连接宿主 Shell 的远程前端
make frontend-build    构建远程前端
make build-server      构建 bin/hdyadmin-template-admin
make build             构建前后端和最终服务端
make clean             清理构建产物，保留前端依赖
make clean-all         清理构建产物、前端依赖和项目内缓存
make docker            构建当前架构镜像并加载到本地 Docker
make docker-push       构建并推送 amd64、arm64 镜像
```

`make clean` 会删除 `bin/`、前端 `dist/`、Module Federation 临时目录、覆盖率报告和嵌入式前端产物，
但保留 `node_modules/` 以便继续开发；需要释放依赖占用空间时使用 `make clean-all`。提交到版本库的
Proto/TypeScript 生成代码、OpenAPI、Descriptor、Wire 文件以及 `.env.local` 不在清理范围内。

`api/pb/`、`frontend/admin/src/generated/api/`、`openapi.yaml` 和 `descriptor.bin` 会提交到版本库，
保证新克隆的项目可以直接执行 `go mod tidy` 和 `go test ./...`。修改 Proto 后必须重新执行
`make gen`。

## Docker 镜像

镜像构建方式与 `hdyadmin-core` 保持一致：根 Makefile 引入独立的 `docker.mk`，
统一使用 Docker Buildx 构建，并写入版本、源码、提交号、构建时间等 OCI 元数据。

本地构建当前主机架构并加载到 Docker：

```bash
make docker
```

默认镜像地址为
`reghub.hdyops.qzz.io/hdyadmin/hdyadmin-template-admin:<当前 Git 版本>`。
仓库、命名空间、镜像名和版本均可覆盖：

```bash
make docker \
  TARGET=registry.example.com \
  PRJ=my-project \
  IMAGE_NAME=my-module \
  IMG_VERSION=v1.0.0
```

登录仓库并发布 `linux/amd64`、`linux/arm64` 多架构镜像：

```bash
make docker-push IMG_VERSION=v1.0.0
```

`docker-push` 会在交互终端安全询问仓库密码；CI 中应通过环境变量或未提交的
`.env.local`/`.env` 设置 `Reghub_UserName`、`Reghub_Pwd`。还可用
`DOCKER_PLATFORMS`、`DOCKER_OUTPUT` 和 `DOCKER_EXTRA_ARGS` 调整 Buildx 行为。

## 目录结构

```text
api/protos/                       Proto 唯一协议源
api/pb/                           生成的 Go API
app/admin/cmd/server/             服务入口和注册资产
app/admin/internal/service/       业务服务
app/admin/internal/server/        gRPC 与资源 HTTP 服务
app/admin/internal/security/cert/ LCM/mTLS 证书引导
frontend/admin/                   管理后台远程模块
```

添加业务时通常按以下顺序进行：

1. 在 `api/protos/` 增加协议。
2. 执行 `make gen`。
3. 增加 Repo、Service，并加入对应的 Wire ProviderSet。
4. 在 gRPC Server 中注册服务。
5. 增加前端 Store、页面和菜单权限。
6. 执行 `make check` 后联调注册流程。

更完整的接入约定可参考 `hdyadmin/docs/独立业务模块开发指南.md`。
