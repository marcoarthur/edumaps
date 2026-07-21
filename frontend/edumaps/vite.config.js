// vite.config.js
import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { svelteTesting } from "@testing-library/svelte/vite";
import tailwindcss from "@tailwindcss/vite";
import { VitePWA } from "vite-plugin-pwa";
import { fileURLToPath, URL } from "node:url";

export default defineConfig(({ mode }) => {
  const isDev = mode === "development";

  return {
    plugins: [
      tailwindcss(),
      svelte(),
      svelteTesting(),
      VitePWA({
        registerType: "autoUpdate",
        includeAssets: ["favicon.svg", "robots.txt"],
        manifest: {
          name: "EduMaps",
          short_name: "EduMaps",
          description:
            "Análise educacional, econômica e demográfica dos municípios brasileiros",
          theme_color: "#1e40af",
          background_color: "#f9fafb",
          display: "standalone",
          start_url: "/",
          icons: [
            { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
            { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
            {
              src: "/icons/icon-512-maskable.png",
              sizes: "512x512",
              type: "image/png",
              purpose: "maskable",
            },
          ],
        },
        workbox: {
          // dados de API não devem ficar em cache "stale" por padrão
          runtimeCaching: [
            {
              urlPattern: /^\/api\//,
              handler: "NetworkFirst",
              options: {
                cacheName: "edumaps-api",
                expiration: { maxAgeSeconds: 300 },
              },
            },
          ],
        },
        devOptions: { enabled: false },
      }),
    ],

    resolve: {
      alias: {
        // aliases por feature, evita "../../../.." nos imports
        "@/features": fileURLToPath(new URL("./src/features", import.meta.url)),
        "@/shared": fileURLToPath(new URL("./src/shared", import.meta.url)),
        "@/app": fileURLToPath(new URL("./src/app", import.meta.url)),
      },
      conditions: process.env.VITEST ? ["browser"] : undefined,
    },

    test: {
      environment: "jsdom",
      setupFiles: ["./src/vitest-setup.js"],
      coverage: {
        provider: "v8",
        include: ["src/features/**/*.{js,svelte}"],
        exclude: ["**/*.test.js"],
      },
    },

    server: {
      port: 5173,
      strictPort: true,
      open: false,
      allowedHosts: ["ubatexu.lan", "molehill-swirl-repair.ngrok-free.dev"],
      proxy: {
        "/api": {
          target: "http://localhost:3000",
          changeOrigin: true,
          secure: false,
        },
        "/analytic-api": {
          target: "http://analytic:8000",
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path.replace(/^\/analytic-api/, ""),
        },
      },
    },

    build: {
      sourcemap: true,
      outDir: "dist",
      rollupOptions: {
        output: {
          // chunk por feature ajuda o nginx com cache de longo prazo por hash
          manualChunks(id) {
            if (id.includes("leaflet")) return "vendor-leaflet";
            if (id.includes("@carbon")) return "vendor-charts";
          },
        },
      },
    },
  };
});
