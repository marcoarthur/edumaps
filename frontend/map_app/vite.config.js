// vite.config.js
import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { svelteTesting } from "@testing-library/svelte/vite";

export default defineConfig(({ mode }) => {
  const isDev = mode === "development";

  return {
    plugins: [svelte(), svelteTesting()],

    // Vite configuration options
    resolve: process.env.VITEST
      ? {
          conditions: ["browser"],
        }
      : undefined,

    // Vitest configuration
    test: {
      environment: "jsdom", // Use 'happy-dom' if you prefer
      setupFiles: ["./src/vitest-setup.js"],
    },

    // -------------------------------------------------------
    // DEV SERVER CONFIG (somente quando rodando `npm run dev`)
    // -------------------------------------------------------
    server: {
      port: 5173,
      strictPort: true,
      open: false,

      // Todo request do frontend para /api é enviado ao Mojolicious
      proxy: {
        "/api": {
          target: "http://localhost:3000",
          changeOrigin: true,
          secure: false,
        },
      },
    },

    // -------------------------------------------------------
    // BUILD DE PRODUÇÃO (usado por npm run build)
    // -------------------------------------------------------
    build: {
      sourcemap: true, // necessário para debug após build
      outDir: "dist/assets",

      rollupOptions: {
        output: {
          entryFileNames: "[name].js",
          chunkFileNames: "[name].js",
          assetFileNames: ({ name }) => {
            if (name && name.endsWith(".css")) {
              return "[name].css";
            }
            return "[name][extname]";
          },
        },
      },
    },
  };
});
