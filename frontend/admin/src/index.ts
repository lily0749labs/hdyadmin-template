import type { TangraModule } from './sdk';
import routes from './routes';
import enUS from './locales/en-US.json';
import zhCN from './locales/zh-CN.json';

// moduleDefinition 是远程模块暴露给宿主 Shell 的统一入口。
// id 同时也是路由、菜单、权限和国际化消息的命名空间。
const moduleDefinition: TangraModule = {
  id: 'template',
  version: '1.0.0',
  routes,
  stores: {},
  locales: {
    'en-US': enUS,
    'zh-CN': zhCN,
  },
};

export default moduleDefinition;
