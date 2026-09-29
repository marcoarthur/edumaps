# Imagem do serviço analítico (edumapsr / Plumber) do compose local.
#
# Espelha o deploy real (Rexfile deploy_analytics_dev): instala o pacote
# `edumapsr` e sobe o Plumber em :8000. Aqui no Docker usamos binários do
# Posit Package Manager (Ubuntu jammy) para o build não compilar tudo do zero.
FROM rocker/r-ver:4.4.1

RUN apt-get update && apt-get install -y --no-install-recommends \
      libpq-dev libssl-dev libcurl4-openssl-dev libxml2-dev \
      libsodium-dev libx11-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Dependências R do DESCRIPTION (mesmo conjunto do deploy). Binários do PPM
# (jammy) => instalação rápida, sem toolchain de compilação.
RUN R -q -e "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest'), Ncpus = max(1L, parallel::detectCores())); install.packages(c('plumber','ggplot2','plotly','jsonlite','DBI','RPostgres','cluster','dbscan','mclust','kernlab','ellmer','yaml'))"

WORKDIR /pkg
COPY . /pkg
RUN R CMD INSTALL --no-multiarch --with-keep.source /pkg

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
