<script setup lang="ts">
import routes from '../routes';
import StandaloneMenu from './Menu.vue';
</script>

<template>
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
