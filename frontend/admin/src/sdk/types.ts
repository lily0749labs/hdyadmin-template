import type { I18n } from 'vue-i18n';
import type { Pinia } from 'pinia';
import type { Router, RouteRecordRaw } from 'vue-router';

// TangraModule 描述远程模块交给宿主注册的全部能力。
export interface TangraModule {
  /** 模块唯一标识，也是国际化消息的顶层命名空间。 */
  id: string;
  /** 模块版本，用于兼容性判断和问题定位。 */
  version: string;
  /** 需要动态挂载到宿主 Router 的页面路由。 */
  routes: RouteRecordRaw[];
  /** 可选的 Pinia Store 工厂集合；当前模板为空。 */
  stores: Record<string, () => unknown>;
  /** 按语言代码组织的模块国际化消息。 */
  locales: Record<string, Record<string, unknown>>;
}

// ShellContext 是宿主提供给远程模块的共享运行时对象。
export interface ShellContext {
  /** 宿主 Router，用于动态增删模块路由。 */
  router: Router;
  /** 宿主 Pinia 实例，保证跨模块状态位于同一容器。 */
  pinia: Pinia;
  /** 宿主 i18n 实例，用于合并模块语言包。 */
  i18n: I18n;
}
