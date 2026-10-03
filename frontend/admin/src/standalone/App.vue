<script setup lang="ts">
import routes from '../routes';
import StandaloneMenu from './Menu.vue';

// 独立调试壳直接复用模块路由生成侧边菜单，避免维护第二份导航配置。
</script>

<template>
  <!-- 此布局只在 standalone 模式使用；连接宿主时由 shell/app-layout 提供外壳。 -->
  <div class="standalone-shell">
    <aside class="standalone-sidebar">
      <div class="standalone-brand">
        <strong>hdyadmin</strong>
        <span>模块本机调试</span>
      </div>

      <nav aria-label="模块页面">
        <StandaloneMenu :routes="routes" />
      </nav>

      <div class="standalone-mode">standalone</div>
    </aside>

    <div class="standalone-main">
      <header class="standalone-header">Template Module</header>
      <RouterView />
    </div>
  </div>
</template>
