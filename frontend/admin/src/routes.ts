import type { RouteRecordRaw } from 'vue-router';

// 模块路由由宿主 Shell 动态注册；路径、权限和国际化键应与 menus.yaml 保持一致。
const routes: RouteRecordRaw[] = [
  {
    path: '/template',
    name: 'TemplateModule',
    // 使用宿主提供的统一页面布局，避免远程模块重复实现导航框架。
    component: () => import('shell/app-layout'),
    redirect: '/template/example',
    meta: {
      order: 900,
      icon: 'lucide:blocks',
      title: 'template.menu.root',
      authority: ['platform:admin', 'tenant:manager'],
    },
    children: [
      {
        path: 'example',
        name: 'TemplateExample',
        meta: {
          icon: 'lucide:flask-conical',
          title: 'template.menu.example',
          authority: ['platform:admin', 'tenant:manager'],
        },
        // 页面组件按需加载，减少远程模块的初始体积。
        component: () => import('./views/example/index.vue'),
      },
    ],
  },
];

export default routes;
