FROM debian:bookworm-slim

# Dependências de sistema e compilação
RUN apt-get update && apt-get install -y \
    build-essential git curl cmake libpq-dev cpanminus \
    libio-socket-ssl-perl liblwp-protocol-https-perl \
    libzip-dev zlib1g-dev libexpat1-dev libminizip-dev \
    gdal-bin \
    && rm -rf /var/lib/apt/lists/*
# gdal-bin: o ogr2ogr lê as camadas geográficas dos jobs de ingestão (marcos de
# km da ANTT #168, setores do Censo #238, xlsx do MapBiomas). No LXC vem do
# deploy_minion_dev; sem ele aqui, esses jobs não rodavam no minion local.

# Instalar Carton e Compilar xlsxio
RUN cpanm Carton && \
    git clone https://github.com/brechtsanders/xlsxio.git /opt/xlsxio && \
    cd /opt/xlsxio && git checkout 0.2.36 && cmake . && make && \
    cp xlsxio_xlsx2csv /usr/local/bin/xlsx2csv_fast

WORKDIR /opt/edumaps/backend
COPY . .

# Hack do cpanfile (baseado no seu Rexfile)
RUN if [ ! -f cpanfile ]; then \
    cp EduMaps-*/cpanfile ./cpanfile || true; \
    sed -i '/EduMaps/d' cpanfile; \
    sed -i '/Contextable/d' cpanfile; \
    fi && carton install

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["web"]
