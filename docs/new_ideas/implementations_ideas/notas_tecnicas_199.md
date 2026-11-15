# Nota técnica 199: suíte do backend em paralelo e backend sem o PDL (#418, #419)

Dois PRs de infraestrutura de teste e build, sem mudança para o usuário:
PR #418 (merge `1bcf790`, sem issue) e PR #420 (merge `6082a60`, fecha a
#419).

## Medições

| | Antes | Depois |
|---|---|---|
| Suíte Perl local | ~3 min 25 s em série | 65–71 s com `-j4` (3 rodadas PASS) |
| Suíte Perl no CI | 2 min 58 s | 78 s (#418), 84 s (#420) |
| Passo do cpanm no CI | 8 min 44 s | 3 min 14 s |
| `carton install` na imagem do backend | (com PDL) | 296 s; build da imagem 5 min 17 s |

## #418: a suíte com `prove -j4`

Com quatro processos, a suíte falhava por duas fontes de concorrência.

1. **A config é uma só.** `app_config.items` é global; dois testes gravando
   limites e SMTP ao mesmo tempo trocavam 429/409 e destinos de e-mail, e uma
   rodada antiga deixou três chaves `canais.email.*` no banco de fixtures.
   `ConfigSnapshot::guardar` agora pega um `pg_advisory_lock` numa **conexão
   própria** (clone do `$dbh`, `lock_timeout` de 15 min) antes da foto, e o
   `restaurar` solta depois de devolver a config. Os testes que gravam config
   rodam um de cada vez; o resto segue em paralelo. Um filho de `fork` (outro
   pid) não restaura nem solta a trava do pai. O `config_snapshot.t` prova a
   espera com um segundo processo.
2. **INEPs de teste repetidos.** Dez INEPs apareciam em ~22 arquivos; um
   arquivo apagava a escola e os dados (contatos, reuniões, pastas) que o
   outro estava usando. Foi a escolha do developer contra a alternativa de
   contar travas, que não cobriria a exclusão em cascata por INEP. Cada
   arquivo tem agora o seu INEP, prefixo `60` (não há UF 60). A `99999999`
   não é criada por ninguém: é a escola inexistente dos 404 e o agregado da
   secretaria no SIOPE. O `t/06-tools/inep_teste_unico.t` acusa as duas
   coisas; contra o main antigo, acusou os 10 conflitos.

As regras foram para o `AGENTS.md` (seção dos testes do backend), e o CI roda
`prove -r -l -j4 t/`.

## #419: fora o PDL

O PDL entrou quando o Perl foi testado como motor estatístico. Desde que o R
assumiu, só o `EduMaps::Analysis::Clusterization` (k-means) o usava, e o único
usuário dele era o `ClusterAnalyzer`; os dois só apareciam em testes. Saíram
os dois módulos, os três testes deles e as três linhas do `cpanfile`. O
`Schema::...::ClusterEscola` ficou (não usa PDL, fora do escopo). O
`[AutoPrereqs]` do `dist.ini` varre o `lib`, então o PDL não volta sozinho.

O ganho maior é no build: o `Dockerfile` do backend faz `COPY . .` antes do
`carton install`, então **toda** mudança de código reinstala as dependências.
O PDL era o pacote mais caro dessa instalação.

## Deploy

No LXC o PDL já instalado pode ficar; o deploy de 16/11 não precisa
desinstalar nada (linha no roteiro `docs/admin/deploy-lxc-2026-11-16.md`).
Imagens locais `backend` e `minion` reconstruídas depois do merge.
