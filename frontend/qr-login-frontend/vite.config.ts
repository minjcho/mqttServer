import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import fs from 'fs'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    https: fs.existsSync('./certs/cert.pem') && fs.existsSync('./certs/key.pem') ? {
      key: fs.readFileSync('./certs/key.pem'),
      cert: fs.readFileSync('./certs/cert.pem')
    } : undefined,
    proxy: {
      '/api': {
        target: 'http://3.36.126.83:8090',
        changeOrigin: true,
        secure: false
      }
    }
  }
})
