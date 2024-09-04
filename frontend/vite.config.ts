import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig(({ mode }) => ({
  plugins: [react()],
  build: {
    outDir: '../static',
    emptyOutDir: true,
    sourcemap: mode === 'development' ? 'inline' : true, // Lighter source maps for development
    minify: mode === 'production', // Only minify in production builds
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom']
        }
      }
    }
  },
  server: {
    open: true, // Automatically open the browser
    hmr: {
      protocol: 'ws', // WebSocket protocol
      host: 'localhost',
    },
    proxy: {
      '/ask': 'http://localhost:5000',
      '/chat': 'http://localhost:5000'
    }
  }
}));
