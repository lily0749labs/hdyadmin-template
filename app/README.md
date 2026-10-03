# `app` 目录说明

本目录保存 hdyadmin 模板模块的服务端应用。当前只有 `admin` 应用，负责启动 gRPC/HTTP 服务、向 Core 注册模块元数据，并提供一个最小的示例接口。

## 目录结构

```text
app/admin/
├── cmd/server/             # 进程入口、依赖注入及随程序发布的嵌入资源
├── configs/               # 数据源、日志和服务监听配置
└── internal/
    ├── security/cert/     # 模块 mTLS 证书初始化
    ├── server/            # gRPC/HTTP 服务及请求校验中间件
    └── service/           # 业务服务实现
```

## 启动流程

1. `cmd/server/main.go` 创建 Bootstrap 上下文。
2. Wire 按 ProviderSet 创建证书管理器、业务服务、gRPC 服务和 HTTP 服务。
3. `newApp` 启动模块注册，并把 OpenAPI、Proto 描述符和菜单定义提交给 hdyadmin Core。
4. Bootstrap 启动两个传输服务；进程退出时停止模块注册和心跳。

## 配置与环境变量

- `configs/server.yaml`：gRPC 监听地址、超时及中间件配置。
- `configs/data.yaml`：数据库和 Redis 连接参数；当前示例服务尚未注入数据仓储。
- `configs/logger.yaml`：日志级别、输出目标和编码格式。
- `MODULE_TLS_DISABLED=1`：仅供本地冒烟测试使用，关闭 gRPC mTLS。
- `MODULE_HTTP_ADDR`：覆盖 HTTP 监听地址，默认 `127.0.0.1:10401`。
- `MODULE_STANDALONE=1`：直接开放业务 HTTP 路由；常规部署由 Core 代理 gRPC。
- `GRPC_ADVERTISE_ADDR`、`HTTP_ADVERTISE_ADDR`、`ADMIN_GRPC_ENDPOINT` 和 `FRONTEND_ENTRY_URL`：控制向 Core 上报的访问地址。

## 生成文件

以下文件不应手工修改，源定义变化后应重新生成：

- `cmd/server/wire_gen.go`：运行 `make wire` 生成。
- `cmd/server/assets/openapi.yaml`：运行 `make openapi` 生成。
- `cmd/server/assets/descriptor.bin`：运行 `make descriptor` 生成，属于二进制文件，无法添加源码注释。
- `cmd/server/assets/frontend-dist/.gitkeep`：仅用于保留空目录。

