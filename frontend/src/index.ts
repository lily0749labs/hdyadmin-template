import type { TangraModule } from './sdk';
import routes from './routes';
import enUS from './locales/en-US.json';
import zhCN from './locales/zh-CN.json';

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
