import {
  createExampleServiceClient,
  type ClientTransport,
} from '../generated/api/domain/example/v1';

const standalone = import.meta.env.MODE === 'standalone';
const MODULE_BASE_URL = standalone ? '/api' : '/admin/v1/modules/template';

async function getAccessToken(): Promise<string | undefined> {
  if (standalone) {
    return undefined;
  }

  const { useAccessStore } = await import('shell/vben/stores');
  const accessStore = useAccessStore();
  return (accessStore as { accessToken?: string }).accessToken;
}

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
      // Keep the status-based fallback when the response is not JSON.
    }
    throw new Error(message);
  }

  const text = await response.text();
  return text ? JSON.parse(text) : {};
}

const transport: ClientTransport = {
  unary: (path, method, body) => request(path, method, body),
  serverStream: () => {
    throw new Error('Server streaming is not supported by this module client.');
  },
  duplexStream: () => {
    throw new Error('Duplex streaming is not supported by this module client.');
  },
};

export const exampleService = createExampleServiceClient(transport);
