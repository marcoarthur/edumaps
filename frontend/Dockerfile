# Build
FROM node:22-slim AS builder
WORKDIR /app
COPY map_app/package*.json ./
RUN npm install
COPY map_app/ ./
RUN npm run build

# Servidor
FROM nginx:alpine
# Copia o build do Vite
COPY --from=builder /app/dist /usr/share/nginx/html
# Copia a sua configuração de Proxy
COPY nginx.conf /etc/nginx/conf.d/default.conf 
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
