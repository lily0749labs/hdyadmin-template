<script setup lang="ts">
import type { RouteRecordRaw } from 'vue-router';
import { useI18n } from 'vue-i18n';

defineOptions({ name: 'StandaloneMenu' });

// 组件递归渲染任意层级路由；parentPath 用于把相对路径展开为完整地址。
withDefaults(
  defineProps<{
    parentPath?: string;
    routes: RouteRecordRaw[];
  }>(),
  { parentPath: '' },
);

const { t, te } = useI18n();

// Vue Router 子路由通常使用相对路径，这里统一拼接并去除重复斜杠。
function fullPath(parentPath: string, path: string): string {
  if (path.startsWith('/')) return path;
  return `${parentPath.replace(/\/$/, '')}/${path}`;
}

// 优先翻译路由标题，缺少语言键时依次回退到原键、路由名和路径。
function title(route: RouteRecordRaw): string {
  const key = route.meta?.title;
  if (typeof key === 'string') return te(key) ? t(key) : key;
  return route.name ? String(route.name) : route.path;
}

// 路由名通常稳定且唯一；没有名称时使用完整路径作为 Vue 列表键。
function routeKey(route: RouteRecordRaw, parentPath: string): string {
  return route.name ? String(route.name) : fullPath(parentPath, route.path);
}
</script>

<template>
  <!-- 有子路由的节点显示分组标题，叶子节点渲染为可导航链接。 -->
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
