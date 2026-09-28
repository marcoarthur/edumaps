# Imagem do frontend do ambiente Docker de desenvolvimento.
#
# Builda a SPA ATUAL (frontend/edumaps — Svelte 5/Vite), não mais o legado
# map_app. Espelha o deploy real (Rexfile deploy_frontend_dev): npm install +
# npm run build, servindo dist/ via nginx.
#
# Build
FROM node:22-slim AS builder
WORKDIR /app
COPY edumaps/package*.json ./
RUN npm ci --no-audit --no-fund
COPY edumaps/ ./
RUN npm run build

# Servidor
FROM nginx:alpine
# Copia o build do Vite (SPA edumaps)
COPY --from=builder /app/dist /usr/share/nginx/html
# Copia a configuração de Proxy (mesmo padrão do deploy real via Rex)
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]