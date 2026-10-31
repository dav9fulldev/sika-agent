import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Servi par le backend FastAPI sous /dashboard/ ; en local, l'API est relayée vers le backend de développement
export default defineConfig({
  base: '/dashboard/',
  plugins: [react()],
  // AG Studio est livré en un seul paquet (≈ 1,7 Mo compressé) : l'avertissement de taille n'apporte rien ici
  build: { chunkSizeWarningLimit: 7000 },
  server: {
    proxy: {
      '/api': 'http://localhost:8001',
    },
  },
})
