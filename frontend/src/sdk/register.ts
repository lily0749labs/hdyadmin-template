import type { ShellContext, TangraModule } from './types';

export function registerModule(ctx: ShellContext, module: TangraModule) {
  for (const route of module.routes) {
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

  for (const [language, messages] of Object.entries(module.locales)) {
    ctx.i18n.global.mergeLocaleMessage(language, { [module.id]: messages });
  }
}
