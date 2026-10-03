# 管理端远程模块说明

本目录是 hdyadmin 模板模块的 Vue 3 前端，通过 Module Federation 由宿主 Shell 动态加载，也可以使用内置调试壳独立运行。

## 关键文件

- `src/index.ts`：暴露给宿主 Shell 的模块定义，包括路由、状态和语言包。
- `src/routes.ts`：模块页面路由；应与服务端 `assets/menus.yaml` 的路径保持一致。
- `src/api/client.ts`：连接生成客户端与实际 HTTP 请求，自动区分独立模式和 Core 代理模式。
- `src/sdk/`：模块与宿主 Shell 之间的最小注册协议。
- `src/standalone.ts`、`src/standalone/`：不依赖宿主 Shell 的本地调试入口和界面。
- `src/generated/`：由 Proto 自动生成，不应手工修改。
- `vite.config.ts`：Module Federation、开发服务器和 standalone API 代理配置；启动时从
  `.runtime/http-endpoint` 读取后端自动分配的端口。
- `vite.hotreload.config.ts`：供不支持 HMR 的嵌入场景使用的构建配置。

## 无法添加行内注释的文件

`package.json`、语言包 JSON 和 `pnpm-lock.yaml` 必须保持严格 JSON/YAML 结构，因此不写行内说明：

- `package.json` 定义构建命令、运行依赖及安全版本覆盖。
- `tsconfig.json` 定义 TypeScript 严格编译、声明文件和输出目录。
- `src/locales/*.json` 保存以模块 ID 为命名空间的国际化文案。
- `pnpm-lock.yaml` 由 pnpm 自动维护，不应手工修改。

常用命令可在仓库根目录运行：`make run-frontend` 启动独立调试页，`make run-frontend-connected` 连接宿主 Shell，`make frontend-build` 构建生产产物。
