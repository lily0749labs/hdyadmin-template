<script setup lang="ts">
import type { RouteRecordRaw } from 'vue-router';
import { useI18n } from 'vue-i18n';

defineOptions({ name: 'StandaloneMenu' });

withDefaults(
  defineProps<{
    parentPath?: string;
    routes: RouteRecordRaw[];
  }>(),
  { parentPath: '' },
);

const { t, te } = useI18n();

function fullPath(parentPath: string, path: string): string {
  if (path.startsWith('/')) return path;
  return `${parentPath.replace(/\/$/, '')}/${path}`;
}

function title(route: RouteRecordRaw): string {
  const key = route.meta?.title;
  if (typeof key === 'string') return te(key) ? t(key) : key;
  return route.name ? String(route.name) : route.path;
}

function routeKey(route: RouteRecordRaw, parentPath: string): string {
  return route.name ? String(route.name) : fullPath(parentPath, route.path);
}
</script>

<template>
  <ul class="standalone-menu">
    <li v-for="route in routes" :key="routeKey(route, parentPath)">
      <template v-if="route.children?.length">
        <div class="standalone-menu-group">{{ title(route) }}</div>
        <StandaloneMenu
          :parent-path="fullPath(parentPath, route.path)"
          :routes="route.children"
        />
      </template>
      <RouterLink
        v-else
        class="standalone-menu-link"
        :to="fullPath(parentPath, route.path)"
      >
        {{ title(route) }}
      </RouterLink>
    </li>
  </ul>
</template>
