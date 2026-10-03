// 声明宿主 Shell 通过 Module Federation 暴露的运行时模块。
// 这些声明只提供编译期类型，实际实现由宿主页面加载。
declare module 'shell/vben/stores' {
  import type { StoreDefinition } from 'pinia';
  export const useAccessStore: StoreDefinition;
}

declare module 'shell/vben/common-ui' {
  import type { Component } from 'vue';
  export const Page: Component;
}

declare module 'shell/app-layout' {
  import type { Component } from 'vue';
  const component: Component;
  export default component;
}
