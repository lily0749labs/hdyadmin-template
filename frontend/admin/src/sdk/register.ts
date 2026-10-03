import type { ShellContext, TangraModule } from './types';

// registerModule 把远程模块的路由和语言包合并到宿主运行时。
export function registerModule(ctx: ShellContext, module: TangraModule) {
  for (const route of module.routes) {
    // 收集当前模块将注册的完整路径，先删除同路径旧路由以支持模块热更新。
    const pathsToRemove = new Set<string>([route.path]);
    for (const child of route.children ?? []) {
      pathsToRemove.add(child.path.startsWith('/')
        ? child.path
        : `${route.path}/${child.path}`);
    }

    for (const existing of ctx.router.getRoutes()) {
      if (pathsToRemove.has(existing.path) && existing.name) {
        ctx.router.removeRoute(existing.name);
      }
    }
    ctx.router.addRoute(route);
  }

  // 以模块 ID 为顶层命名空间，防止不同远程模块的语言键相互覆盖。
  for (const [language, messages] of Object.entries(module.locales)) {
    ctx.i18n.global.mergeLocaleMessage(language, { [module.id]: messages });
  }
}
