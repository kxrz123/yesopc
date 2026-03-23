import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react-swc';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '127.0.0.1',
    port: 5199,
    strictPort: true,
    hmr: {
      host: '127.0.0.1',
      port: 5199,
      protocol: 'ws',
    },
    // 开发时 content-api（go-zero）默认 8888；见 services/content-api/README.md
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8888',
        changeOrigin: true,
      },
    },
  },
});

