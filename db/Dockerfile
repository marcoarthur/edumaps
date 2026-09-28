# Imagem do banco do ambiente Docker de desenvolvimento.
#
# Base: pgvector/pgvector:pg16-bookworm (Debian 12). Espelha o ambiente real,
# que no Rexfile instala postgresql-16-postgis-3 + postgresql-16-pgvector sobre
# Debian. O pgvector já vem na base, na versão 0.8.6 (a mesma do container real).
#
# Por que NÃO postgis/postgis:16-3.5 — aquela imagem é Debian 11 (bullseye),
# com curl 7.74 e GDAL 3.2.2. Ela também não lia a resposta do cdn.jsdelivr.net
# (ver nota do GDAL_HTTP_HEADERS abaixo) e ainda pinava curl/ca-certificates em
# versões que saíram do pool do apt (404). O bookworm é o mesmo Debian do
# ambiente real e resolve os dois pontos.
FROM pgvector/pgvector:pg16-bookworm

# PGDG já está configurado na base. PostGIS e o OGR_FDW vêm do mesmo repositório
# do Postgres 16, então ficam versionados juntos.
#
# ca-certificates é obrigatório: sem o bundle, o libcurl do GDAL falha com
# "error setting certificate file" e o /vsicurl da migration raw_countries não
# consegue validar o TLS (a base pgvector não traz o pacote).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    postgresql-16-postgis-3 \
    postgresql-16-postgis-3-scripts \
    postgresql-16-ogr-fdw \
    && rm -rf /var/lib/apt/lists/*

# A migration raw_countries usa /vsicurl (OGR_FDW) para baixar um GeoJSON.
# O resolver do Docker devolve AAAA e o container não tem rota IPv6, então o
# libcurl tentava ::1 e falhava sem fallback. Preferir IPv4 no getaddrinfo.
RUN printf 'precedence ::ffff:0:0/96  100\n' >> /etc/gai.conf

# A migration raw_countries usa /vsicurl (OGR_FDW) contra o cdn.jsdelivr.net,
# que é Cloudflare. Dependendo do edge, a resposta vem em streaming: HTTP 200
# com Transfer-Encoding: chunked e sem Content-Length. O callback de escrita do
# vsicurl recusa corpo chunked e o GDAL reporta "unable to connect to data
# source" — mesmo com o log do curl mostrando o 200, o que confunde o
# diagnóstico. Pedir identity reduz a chance de o edge responder assim, mas
# NÃO é garantido: da rede de desenvolvimento o resultado variou na mesma
# sessão (3/3 ok, depois 0/6). Para um banco novo, o jeito confiável é servir o
# mesmo arquivo localmente e apontar cdn.jsdelivr.net para 127.0.0.1 — o
# procedimento está em memory.md.
ENV GDAL_HTTP_HEADERS="Accept-Encoding: identity"
