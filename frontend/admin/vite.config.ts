import { federation } from '@module-federation/vite';
import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vite';

export default defineConfig(({ command, mode }) => {
  const standalone = mode === 'standalone';

  return {
    base: command === 'serve' ? '/' : '/modules/template/',
    plugins: [
      vue(),
      federation({
        name: 'template',
        filename: 'remoteEntry.js',
        remotes: {
          shell: {
            type: 'module',
            name: 'shell',
            entry:
              command === 'serve'
                ? 'http://localhost:5666/remoteEntry.js'
                : '/remoteEntry.js',
          },
        },
        exposes: {
          './module': './src/index.ts',
        },
        shared: {
          vue: { singleton: true, requiredVersion: '^3.5.13' },
          'vue-router': { singleton: true, requiredVersion: '^4.5.0' },
          pinia: { singleton: true, requiredVersion: '^2.2.2' },
          'ant-design-vue': { singleton: true, requiredVersion: '^4.2.6' },
        },
        dts: false,
      }),
    ],
    server: {
      port: 3011,
      strictPort: true,
      origin: 'http://localhost:3011',
      cors: true,
      ...(standalone
        ? {
            proxy: {
              '/api': {
                target: 'http://127.0.0.1:10401',
                changeOrigin: true,
                rewrite: (path: string) => path.replace(/^\/api/, ''),
              },
            },
          }
        : {}),
    },
    build: {
      target: 'esnext',
      minify: true,
    },
  };
});
