import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/template',
    name: 'TemplateModule',
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
        component: () => import('./views/example/index.vue'),
      },
    ],
  },
];

export default routes;
