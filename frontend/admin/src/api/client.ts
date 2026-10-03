import {
  createExampleServiceClient,
  type ClientTransport,
} from '../generated/api/domain/example/v1';

// standalone 模式直接访问模块 HTTP 服务；联调/生产模式统一经过 Core 动态代理。
const standalone = import.meta.env.MODE === 'standalone';
const MODULE_BASE_URL = standalone ? '/api' : '/admin/v1/modules/template';

// 从宿主 Shell 的 Pinia Store 延迟读取访问令牌，避免 standalone 模式加载远程依赖。
async function getAccessToken(): Promise<string | undefined> {
  if (standalone) {
    return undefined;
  }

  const { useAccessStore } = await import('shell/vben/stores');
  const accessStore = useAccessStore();
  return (accessStore as { accessToken?: string }).accessToken;
}

// request 将生成客户端的传输调用转换为标准 Fetch 请求，并统一处理鉴权和错误响应。
async function request(path: string, method: string, body: string | null): Promise<unknown> {
  const token = await getAccessToken();
  const response = await fetch(`${MODULE_BASE_URL}/${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body,
  });

  if (!response.ok) {
    let message = `HTTP error: ${response.status}`;
    try {
      const errorBody = await response.json() as { message?: string };
      message = errorBody.message || message;
    } catch {
      // 响应不是 JSON 时保留基于 HTTP 状态码的兜底错误信息。
    }
    throw new Error(message);
  }

  const text = await response.text();
  return text ? JSON.parse(text) : {};
}

// 当前示例协议只有一元 RPC；流式方法显式报错，避免调用方误以为已经实现。
const transport: ClientTransport = {
  unary: (path, method, body) => request(path, method, body),
  serverStream: () => {
    throw new Error('Server streaming is not supported by this module client.');
  },
  duplexStream: () => {
    throw new Error('Duplex streaming is not supported by this module client.');
  },
};

// 业务页面通过此实例调用 ExampleService，无需感知底层路由和鉴权差异。
export const exampleService = createExampleServiceClient(transport);
