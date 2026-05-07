FROM debian:bookworm-slim

# Dependências de sistema e compilação
RUN apt-get update && apt-get install -y \
    build-essential git curl cmake libpq-dev cpanminus \
    libio-socket-ssl-perl liblwp-protocol-https-perl \
    libzip-dev zlib1g-dev libexpat1-dev libminizip-dev \
    && rm -rf /var/lib/apt/lists/*

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
