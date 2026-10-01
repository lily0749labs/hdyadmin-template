import { createApp, defineComponent, h } from 'vue';
import { createI18n } from 'vue-i18n';
import {
  createRouter,
  createWebHashHistory,
  RouterView,
  type RouteRecordRaw,
} from 'vue-router';

import StandaloneApp from './standalone/App.vue';
import enUS from './locales/en-US.json';
import zhCN from './locales/zh-CN.json';
import routes from './routes';
import './standalone.css';

const StandaloneRouterView = defineComponent({
  name: 'StandaloneRouterView',
  setup: () => () => h(RouterView),
});

function createStandaloneRoutes(records: RouteRecordRaw[]): RouteRecordRaw[] {
  return records.map((record) => {
    if (!record.children?.length) return { ...record };
    return {
      ...record,
      component: StandaloneRouterView,
      children: createStandaloneRoutes(record.children),
    } as RouteRecordRaw;
  });
}

function firstPagePath(records: RouteRecordRaw[], parentPath = ''): string | undefined {
  for (const record of records) {
    const path = record.path.startsWith('/')
      ? record.path
      : `${parentPath.replace(/\/$/, '')}/${record.path}`;
    const childPath = record.children && firstPagePath(record.children, path);
    if (childPath) return childPath;
    if (!record.children?.length) return path;
  }
  return undefined;
}

const defaultPath = firstPagePath(routes) ?? '/';
const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: defaultPath },
    ...createStandaloneRoutes(routes),
    { path: '/:pathMatch(.*)*', redirect: defaultPath },
  ],
});

const i18n = createI18n({
  legacy: false,
  locale: navigator.language.startsWith('en') ? 'en-US' : 'zh-CN',
  fallbackLocale: 'zh-CN',
  messages: {
    'en-US': { template: enUS },
    'zh-CN': { template: zhCN },
  },
});

createApp(StandaloneApp).use(router).use(i18n).mount('#app');
