// vite.config.js
import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import fs from "node:fs";
import path from "node:path";

// ---------------------------------------------------------------------
// Vite configuration
// ---------------------------------------------------------------------
export default defineConfig({
  plugins: [svelte()],

  // Build output goes directly into the folder you’ll serve from Mojolicious
  build: {
    outDir: "dist/assets",
    rollupOptions: {
      output: {
        // entry points (e.g., main.js) → index.js (no hash)
        entryFileNames: "[name].js",
        // code‑splitting chunks → keep name, no hash
        chunkFileNames: "[name].js",
        // CSS assets → index.css (no hash)
        assetFileNames: ({ name }) => {
          if (name && name.endsWith(".css")) {
            return "[name].css";
          }
          // other assets (images, fonts, etc.)
          return "[name][extname]";
        },
      },
    },
  },
});
