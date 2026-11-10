# Imagem do serviço analítico (edumapsr / Plumber) do compose local.
#
# Espelha o deploy real (Rexfile deploy_analytics_dev): instala o pacote
# `edumapsr` e sobe o Plumber em :8000. Aqui no Docker usamos binários do
# Posit Package Manager (Ubuntu jammy) para o build não compilar tudo do zero.
FROM rocker/r-ver:4.4.1

# Bibliotecas de sistema: as do pacote (libpq, libsodium do plumber, ...) e as
# do devtools e dependências (libgit2 do gert; harfbuzz/fribidi/freetype/
# fontconfig/png/jpeg/tiff do textshaping/ragg/systemfonts; libuv do fs).
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpq-dev libssl-dev libcurl4-openssl-dev libxml2-dev \
      libsodium-dev libx11-dev ca-certificates \
      libgit2-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev \
      libfontconfig1-dev libpng-dev libjpeg-dev libtiff5-dev libuv1-dev \
    && rm -rf /var/lib/apt/lists/*

# Dependências R: TODAS as do DESCRIPTION (Depends, Imports e Suggests, #363),
# lidas pelo inst/scripts/dependencias.R — sem lista à mão. Binários do PPM
# (jammy) => instalação rápida, sem toolchain de compilação. Só o DESCRIPTION
# e o script entram aqui, para a camada não refazer a cada mudança no código.
COPY DESCRIPTION /tmp/edumapsr/DESCRIPTION
COPY inst/scripts/dependencias.R /tmp/edumapsr/dependencias.R
RUN Rscript /tmp/edumapsr/dependencias.R instalar /tmp/edumapsr/DESCRIPTION \
      https://packagemanager.posit.co/cran/__linux__/jammy/latest

# eduBR (Suggests; Assistente de Relatório, #219) em commit FIXO do GitHub,
# mais as dependências que a Fase 0 mostrou faltar: dbplyr (Imports do
# eduBR) e parsnip/broom (Suggests do eduBR, exigidos por
# `tendencia_ideb_regiao`). `upgrade = 'never'` não mexe no que já está
# instalado acima.
ARG EDUBR_REF=2dc9af929742896d575e2e147e7e2c253a346ba8
RUN R -q -e "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest'), Ncpus = max(1L, parallel::detectCores())); install.packages(c('remotes','dplyr','dbplyr','tibble','rlang','bit64','parsnip','broom')); remotes::install_github('marcoarthur/eduBR@${EDUBR_REF}', upgrade = 'never', dependencies = NA); stopifnot(requireNamespace('eduBR', quietly = TRUE))"

WORKDIR /pkg
COPY . /pkg
RUN R CMD INSTALL --no-multiarch --with-keep.source /pkg
# Build falha se faltar qualquer dependência do DESCRIPTION (inclui o eduBR).
RUN Rscript /pkg/inst/scripts/dependencias.R verificar /pkg/DESCRIPTION

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
