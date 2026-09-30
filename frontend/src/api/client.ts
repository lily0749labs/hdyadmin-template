import { useAccessStore } from 'shell/vben/stores';

import {
  createExampleServiceClient,
  type ClientTransport,
} from '../generated/api/domain/example/v1';

const MODULE_BASE_URL = '/admin/v1/modules/template';

async function request(path: string, method: string, body: string | null): Promise<unknown> {
  const accessStore = useAccessStore();
  const token = (accessStore as { accessToken?: string }).accessToken;
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
  unary(path, method, body) {
    return request(path, method, body);
  },
  serverStream() {
    throw new Error('Template module does not expose server streams');
  },
  duplexStream() {
    throw new Error('Template module does not expose duplex streams');
  },
};

export const exampleService = createExampleServiceClient(transport);
