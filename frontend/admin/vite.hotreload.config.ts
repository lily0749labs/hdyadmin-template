import originalConfig from './vite.config';
import { mergeConfig, type Plugin, type UserConfig } from 'vite';

// 以生产构建上下文解析基础配置，再覆盖不适合嵌入式热重载场景的选项。
const resolved = typeof originalConfig === 'function'
  ? originalConfig({ command: 'build', mode: 'development' })
  : originalConfig;

const disableHmr: Plugin = {
  // 某些宿主会自行刷新远程模块；关闭 Vite WebSocket，避免重复 HMR 或连接报错。
  name: 'disable-hmr',
  enforce: 'post',
  config() {
    return { server: { hmr: false } };
  },
  configureServer(server) {
    if (server.ws && typeof server.ws.close === 'function') {
      server.ws.close();
    }
  },
};

const merged = mergeConfig(resolved as UserConfig, {
  // 远程资源始终由宿主的模块前缀提供，并允许容器或代理环境中的任意主机名。
  base: '/modules/template/',
  server: { allowedHosts: true, hmr: false },
});

merged.plugins = [
  // 后置插件确保基础配置中的 HMR 设置最终被禁用。
  ...(Array.isArray(merged.plugins) ? merged.plugins : []),
  disableHmr,
];

export default merged;
