/// <reference types="vite/client" />

// 为 TypeScript 补充 Vue 单文件组件模块声明，使 .vue 导入具有组件类型。
declare module '*.vue' {
  import type { DefineComponent } from 'vue';
  const component: DefineComponent<Record<string, unknown>, Record<string, unknown>, unknown>;
  export default component;
}
