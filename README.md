# hdyadmin 模块模板

这是从 `hdyadmin-notify` 提炼出的独立业务模块模板，用于快速创建可接入
`hdyadmin-core` 的 Go/Kratos 后端和 Vue 远程模块。

模板只保留一条可验证的最小链路：

- Proto 同时生成 Go、TypeScript、OpenAPI 和 Descriptor。
- 后端启动后向 `hdyadmin-core` 注册模块、接口、菜单和前端入口。
- gRPC 支持通过 `hdyadmin-lcm` 引导 mTLS 证书。
- 前端通过 Module Federation 被 `hdyadmin-frontend` 动态加载。
- 示例接口可验证 Core 的动态 HTTP/gRPC 代理是否可用。

## 快速创建新模块

可以一条命令完成模板克隆、模块初始化、代码生成、Go 测试、服务端构建以及
前端依赖安装和构建，不依赖 `gohdy`：

```bash
./scripts/new-module.sh \
  --target /path/to/examples/tangra-vip \
  --id vip \
  --name "VIP" \
  --project-prefix tangra \
  --go-module github.com/example/tangra-vip
```

`new-module.sh` 已包含模板克隆和初始化逻辑，可以单独复制到任意目录执行，不依赖
`gohdy` 或其他项目脚本。它会统一更新 Go module、注册信息、菜单、前端路由、开发端口、
Docker 镜像名和调试配置。仅希望跳过前端依赖安装和构建时传入 `--skip-frontend`；调试
脚本流程时可用 `--skip-check` 跳过最终检查。可通过 `--repo-url` 使用其他远程或本地模板
仓库，通过 `--branch` 指定模板分支。`--project-prefix` 用于配置项目、可执行文件和镜像的
命名前缀，默认值为 `hdyadmin`；例如传入 `--project-prefix tangra --id vip` 会生成
`tangra-vip-admin`。

模块 ID 只能包含小写字母、数字和连字符，一旦部署后不应再修改。初始化完成后建议提交
一次基线版本，再开始添加业务代码。

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

分别启动后端和远程前端：

```bash
make run-server
make run-frontend
```

不连接 hdyadmin 外部服务时，可以在 VS Code 中直接运行
`Debug hdyadmin-template backend (standalone)`。联调完整环境时，先创建 `.env.local`，再运行
`Debug hdyadmin-template connected (backend + frontend)`。

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
make frontend-build    构建远程前端
make build-server      构建 bin/hdyadmin-template-admin
make build             构建前后端和最终服务端
make docker            构建容器镜像
```

`api/pb/`、`frontend/admin/src/generated/api/`、`openapi.yaml` 和 `descriptor.bin` 会提交到版本库，
保证新克隆的项目可以直接执行 `go mod tidy` 和 `go test ./...`。修改 Proto 后必须重新执行
`make gen`。

## 目录结构

```text
api/protos/                       Proto 唯一协议源
api/pb/                           生成的 Go API
app/admin/cmd/server/             服务入口和注册资产
app/admin/internal/service/       业务服务
app/admin/internal/server/        gRPC 与资源 HTTP 服务
app/admin/internal/security/cert/ LCM/mTLS 证书引导
frontend/admin/                   管理后台远程模块
scripts/new-module.sh             克隆模板并初始化的一键创建入口
```

添加业务时通常按以下顺序进行：

1. 在 `api/protos/` 增加协议。
2. 执行 `make gen`。
3. 增加 Repo、Service，并加入对应的 Wire ProviderSet。
4. 在 gRPC Server 中注册服务。
5. 增加前端 Store、页面和菜单权限。
6. 执行 `make check` 后联调注册流程。

更完整的接入约定可参考 `hdyadmin/docs/独立业务模块开发指南.md`。
