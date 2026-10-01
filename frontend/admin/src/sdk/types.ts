import type { I18n } from 'vue-i18n';
import type { Pinia } from 'pinia';
import type { Router, RouteRecordRaw } from 'vue-router';

export interface TangraModule {
  id: string;
  version: string;
  routes: RouteRecordRaw[];
  stores: Record<string, () => unknown>;
  locales: Record<string, Record<string, unknown>>;
}

export interface ShellContext {
  router: Router;
  pinia: Pinia;
  i18n: I18n;
}
