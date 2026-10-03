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

// standalone 模式没有宿主布局，用一个纯 RouterView 替代 shell/app-layout。
const StandaloneRouterView = defineComponent({
  name: 'StandaloneRouterView',
  setup: () => () => h(RouterView),
});

// 递归复制业务路由，并把依赖宿主的父级布局替换为本地 RouterView。
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

// 找到第一条叶子页面路由，作为调试壳根路径和未知路径的默认跳转目标。
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
// Hash 路由无需服务端 fallback 配置，适合直接由 Vite 提供本地调试页面。
const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: defaultPath },
    ...createStandaloneRoutes(routes),
    { path: '/:pathMatch(.*)*', redirect: defaultPath },
  ],
});

// 根据浏览器语言选择中英文，并保持与宿主相同的模块 ID 命名空间。
const i18n = createI18n({
  legacy: false,
  locale: navigator.language.startsWith('en') ? 'en-US' : 'zh-CN',
  fallbackLocale: 'zh-CN',
  messages: {
    'en-US': { template: enUS },
    'zh-CN': { template: zhCN },
  },
});

// 挂载仅供本地使用的轻量调试壳。
createApp(StandaloneApp).use(router).use(i18n).mount('#app');
