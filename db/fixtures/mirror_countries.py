#!/usr/bin/env python3
"""Espelho HTTPS local do GeoJSON de países, para o deploy do Sqitch em CI.

Por que existe
--------------
A migration `raw_countries` lê um arquivo remoto via OGR FDW:

    datasource '/vsicurl/https://cdn.jsdelivr.net/gh/johan/world.geo.json/countries.geo.json'

O `cdn.jsdelivr.net` é Cloudflare e, dependendo do edge, responde
`Transfer-Encoding: chunked` sem `Content-Length`. O callback de escrita do
`/vsicurl` recusa corpo chunked e o GDAL reporta

    unable to connect to data source "..."

mesmo com HTTP 200 no log do curl — o sintoma engana o diagnóstico. Nenhuma
knob do GDAL resolve de forma confiável (chegou a passar 3/3 e depois 0/6 na
mesma sessão, ver memory.md).

A migration **não pode ser alterada** (o checksum do Sqitch já está em
ambiente implantado) e o `datasource` está fixo no texto. A saída é fazer o
hostname resolver localmente e servir o mesmo arquivo por HTTPS, com uma CA
própria. É o mesmoespelho que o ambiente de desenvolvimento já usa, aqui
automatizado e sem depender da rede.

Uso
---
    # 1. gera a CA e o certificado (o host precisa ter openssl)
    db/fixtures/mirror_countries.py cert $TMPDIR

    # 2. sobe o servidor (porta 443 por padrão)
    db/fixtures/mirror_countries.py serve $TMPDIR 443 \
        --de db/fixtures/countries.geo.json

No CI, o espelho roda num container com `--network-alias cdn.jsdelivr.net`
para que o DNS do Docker o resolva com o hostname que a migration pede — mais
simples e mais portável que mexer no `/etc/hosts` do container do Postgres. O
container do Postgres recebe `CURL_CA_BUNDLE=<ca.crt>` para confiar na CA.
"""

from __future__ import annotations

import functools
import http.server
import io
import os
import re
import shutil
import ssl
import sys

# Caminho que a migration pede. O docroot precisa reproduzi-lo, para que o
# pedido do GDAL case com o arquivo sem reescrita de URL.
CAMINHO_GEOMETRIA = 'gh/johan/world.geo.json/countries.geo.json'


def preparar_docroot(diretorio: str, fonte: str) -> str:
    """Monta o docroot colocando o GeoJSON no caminho que a migration pede."""
    docroot = os.path.join(diretorio, 'docroot')
    alvo = os.path.join(docroot, CAMINHO_GEOMETRIA)
    os.makedirs(os.path.dirname(alvo), exist_ok=True)
    if os.path.exists(fonte) and os.path.realpath(fonte) != os.path.realpath(alvo):
        import shutil
        shutil.copyfile(fonte, alvo)
    return docroot


class Handler(http.server.SimpleHTTPRequestHandler):
    """Handler estático com suporte a `Range`.

    O `SimpleHTTPRequestHandler` da stdlib ignora `Range` e responde 200 com o
    arquivo inteiro. O `/vsicurl` do GDAL abre o datasource com um GET
    range (`Range: bytes=0-16383`) para ler só o cabeçalho GeoJSON e, ao receber
    200 em vez de 206, aborta com

        Range downloading not supported by this server!

    por isso o espelho precisa responder 206 com `Content-Range`. É também o
    que um servidor estático de verdade (nginx, o que o ambiente de
    desenvolvimento usa) faz.
    """

    def send_head(self):  # type: ignore[override]
        caminho = self.translate_path(self.path)
        if os.path.isdir(caminho):
            return super().send_head()
        try:
            self.range = self.headers.get('Range')
            if not self.range:
                return super().send_head()
            with open(caminho, 'rb') as fh:
                dados = fh.read()
        except OSError:
            self.send_error(404, 'File not found')
            return None

        m = re.fullmatch(r'bytes=(\d*)-(\d*)', self.range.strip())
        if not m:
            self.range = None
            return super().send_head()
        inicio, fim = m.group(1), m.group(2)
        if inicio == '' and fim == '':
            self.send_error(400, 'Invalid Range')
            return None
        if inicio == '':                      # bytes=-N: os N últimos
            n = int(fim)
            ini, f = max(0, len(dados) - n), len(dados) - 1
        else:
            ini = int(inicio)
            f = int(fim) if fim else len(dados) - 1
        if ini >= len(dados):
            self.send_response(416)
            self.send_header('Content-Range', f'bytes */{len(dados)}')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return None
        f = min(f, len(dados) - 1)
        corpo = dados[ini:f + 1]

        self.send_response(206)
        self.send_header('Content-type',
                         self.guess_type(caminho) or 'application/octet-stream')
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Content-Range', f'bytes {ini}-{f}/{len(dados)}')
        self.send_header('Content-Length', str(len(corpo)))
        self.end_headers()
        return io.BytesIO(corpo)

    def copyfile(self, origem, saida):  # type: ignore[override]
        # getrange() chama copyfile(); o BytesIO acima já traz só o trecho.
        shutil.copyfileobj(origem, saida)


def servir(diretorio: str, porta: int, cert: str, chave: str) -> None:
    handler = functools.partial(Handler, directory=diretorio)
    # SimpleHTTPRequestHandler manda Content-Length e serve em HTTP/1.0 com
    # Connection: close — é o framing que o /vsicurl aceita.
    httpd = http.server.ThreadingHTTPServer(('0.0.0.0', porta), handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile=cert, keyfile=chave)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)

    # Uma linha por requisição, em stderr: o log do job mostra o que o GDAL pede.
    def log(msg: str) -> None:
        print(msg, file=sys.stderr, flush=True)

    httpd.RequestHandlerClass.log_message = log  # type: ignore[attr-defined]
    log(f'mirror: servindo {diretorio} em https://0.0.0.0:{porta}')
    httpd.serve_forever()


def principal() -> int:
    if len(sys.argv) < 3 or sys.argv[1] not in ('cert', 'serve'):
        print(__doc__, file=sys.stderr)
        print('\nuso: mirror_countries.py cert|serve <dir> [porta]',
              file=sys.stderr)
        return 2
    acao, diretorio = sys.argv[1], sys.argv[2]
    os.makedirs(diretorio, exist_ok=True)
    ca = os.path.join(diretorio, 'ca.crt')
    srv_crt = os.path.join(diretorio, 'srv.crt')
    srv_key = os.path.join(diretorio, 'srv.key')

    if acao == 'cert':
        import subprocess
        def openssl(*args: str) -> None:
            subprocess.run(('openssl',) + args, check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        openssl('req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                '-keyout', os.path.join(diretorio, 'ca.key'),
                '-out', ca, '-days', '3650', '-subj', '/CN=edumaps-ci-ca')
        openssl('req', '-newkey', 'rsa:2048', '-nodes',
                '-keyout', srv_key, '-out', os.path.join(diretorio, 'srv.csr'),
                '-subj', '/CN=cdn.jsdelivr.net')
        with open(os.path.join(diretorio, 'ext.cnf'), 'w') as fh:
            fh.write('subjectAltName=DNS:cdn.jsdelivr.net,DNS:localhost\n'
                     'basicConstraints=CA:FALSE\nextendedKeyUsage=serverAuth\n')
        openssl('x509', '-req', '-in', os.path.join(diretorio, 'srv.csr'),
                '-CA', ca, '-CAkey', os.path.join(diretorio, 'ca.key'),
                '-CAcreateserial', '-out', srv_crt, '-days', '3650',
                '-extfile', os.path.join(diretorio, 'ext.cnf'))
        print(f'CA:     {ca}')
        print(f'server: {srv_crt}')
        return 0

    porta = int(sys.argv[3]) if len(sys.argv) > 3 else 443
    fonte = None
    if '--de' in sys.argv:
        fonte = sys.argv[sys.argv.index('--de') + 1]
    docroot = preparar_docroot(diretorio, fonte) if fonte \
        else os.path.join(diretorio, 'docroot')
    alvo = os.path.join(docroot, CAMINHO_GEOMETRIA)
    if not os.path.exists(alvo):
        print(f'ERRO: {alvo} não existe — passe --de <countries.geo.json>',
              file=sys.stderr)
        return 1
    servir(docroot, porta, srv_crt, srv_key)
    return 0


if __name__ == '__main__':
    sys.exit(principal())
