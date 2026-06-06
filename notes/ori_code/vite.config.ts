import path from 'path';
import { defineConfig } from '@lark-apaas/fullstack-vite-preset';

export default defineConfig({
  assetsInclude: ['**/*.data', '**/*.wasm'],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'client/src'),
    },
  },
  server: {
    proxy: {
      '/feishu-api': {
        target: 'https://open.feishu.cn',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/feishu-api/, ''),
      },
      '/lark-api': {
        target: 'https://open.larkoffice.com',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/lark-api/, ''),
      }
    }
  }
});
