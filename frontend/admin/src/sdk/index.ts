// 对外集中导出宿主注册函数和模块协议类型，避免调用方依赖 SDK 内部文件结构。
export { registerModule } from './register';
export type { ShellContext, TangraModule } from './types';
