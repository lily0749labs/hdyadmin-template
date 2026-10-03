import { federation } from '@module-federation/vite';
import vue from '@vitejs/plugin-vue';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, loadEnv } from 'vite';

const projectRoot = fileURLToPath(new URL('../..', import.meta.url));
const runtimeDir = resolve(projectRoot, process.env.MODULE_RUNTIME_DIR || '.runtime');
const runtimeEndpointFile = resolve(runtimeDir, 'http-endpoint');

// 等待 standalone 后端发布系统分配的真实端口，并通过健康检查排除崩溃遗留的旧地址。
async function waitForStandaloneBackend(timeout = 15_000): Promise<string> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    try {
      const endpoint = (await readFile(runtimeEndpointFile, 'utf8')).trim();
      const response = await fetch(`${endpoint}/health`, {
        signal: AbortSignal.timeout(500),
      });
      if (response.ok) return endpoint;
    } catch {
      // 后端尚未完成监听时短暂等待；超时后再向开发者报告明确错误。
    }
    await new Promise((resolveWait) => setTimeout(resolveWait, 200));
  }
  throw new Error(
    `等待 standalone 后端超时，请先启动 make run；地址文件：${runtimeEndpointFile}`,
  );
}

// 同一份配置同时支持 standalone 本地调试、connected 联调和生产构建。
export default defineConfig(async ({ command, mode }) => {
  const env = loadEnv(mode, projectRoot, 'DMIN_');
  const shellBaseURL = (
    env.ADMIN_SHELL_URL || 'http://localhost:8080'
  ).replace(/\/+$/, '');
  const standalone = mode === 'standalone';
  const standaloneBackend = standalone
    ? await waitForStandaloneBackend()
    : 'http://127.0.0.1';

  return {
    // 开发服务器从根路径提供资源；生产产物由 Core 挂载到模块专属前缀。
    base: command === 'serve' ? '/' : '/modules/template/',
    plugins: [
      vue(),
      // 将模块定义暴露为 remoteEntry.js，供 hdyadmin 宿主 Shell 动态加载。
      federation({
        name: 'template',
        filename: 'remoteEntry.js',
        remotes: {
          // 开发时连接本机宿主，生产时使用同源宿主入口。
          shell: {
            type: 'module',
            name: 'shell',
            entry:
              command === 'serve'
                ? `${shellBaseURL}/remoteEntry.js`
                : '/remoteEntry.js',
          },
        },
        exposes: {
          // 宿主通过 template/module 获取 src/index.ts 导出的模块定义。
          './module': './src/index.ts',
        },
        shared: {
          // UI 基础依赖由宿主与远程模块共享单例，避免多实例上下文不一致。
          vue: { singleton: true, requiredVersion: '^3.5.13' },
          'vue-router': { singleton: true, requiredVersion: '^4.5.0' },
          pinia: { singleton: true, requiredVersion: '^2.2.2' },
          'ant-design-vue': { singleton: true, requiredVersion: '^4.2.6' },
        },
        dts: false,
      }),
    ],
    server: {
      port: 3011,
      strictPort: true,
      origin: 'http://localhost:3011',
      cors: true,
      // standalone 模式把 /api 转发到模块 HTTP 服务；connected 模式由 Core 代理。
      ...(standalone
        ? {
          proxy: {
            '/api': {
              target: standaloneBackend,
              changeOrigin: true,
              rewrite: (path: string) => path.replace(/^\/api/, ''),
            },
          },
        }
        : {}),
    },
    build: {
      // 宿主运行环境支持现代模块语法，无需降级转译。
      target: 'esnext',
      minify: true,
    },
  };
});
