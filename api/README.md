# API 目录说明

本目录保存模块的 Proto 源协议、Buf 配置和已提交的生成代码。协议源文件位于 `protos/`，生成后的 Go 代码位于 `pb/`。

## 配置文件

- `buf.yaml`：声明模块、外部协议依赖、Lint 和破坏性变更规则。
- `buf.gen.yaml`：生成 Go Protobuf、gRPC、Kratos HTTP 和日志脱敏代码。
- `buf.typescript.gen.yaml`：生成远程前端使用的 TypeScript HTTP 客户端。
- `buf.openapi.gen.yaml`：生成模块注册时提交给 Core 的 OpenAPI 文档。
- `buf.lock`：Buf 自动维护的依赖锁文件，不应手工修改。

修改 `protos/` 后执行 `make gen`，并提交同步变化的 Go、TypeScript、OpenAPI 和二进制 Descriptor。`pb/` 中带有 `Code generated` 标记的文件均为生成物，不应直接添加或修改注释。

