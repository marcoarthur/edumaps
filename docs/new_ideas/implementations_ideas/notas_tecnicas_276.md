# Nota técnica 276: a folha detalhada do total da Secretaria (#585)

Achado QE-01 da quarta avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-24-p2-piso-resposta-tce.md`, a
resposta ao tribunal sobre o piso em Cuiabá). Modo autônomo autorizado pelo
developer (até 25/11, 9h). Um PR: #586 (merge `12daeeb`).

## O problema

- **QE-01 (atrapalha).** A folha detalhada (por pessoa) existia só por
  escola. Onde o município declara no código da Secretaria (99999999), as
  linhas estavam carregadas e não apareciam: o painel da Secretaria
  desabilitava "Ver folha completa", e a ajuda dizia "a folha detalhada não
  existe".
- A contagem do piso na rede (#575) apontava 1.421 pessoas só na
  Secretaria em Cuiabá 2026 que ninguém conseguia conferir.

## Decisões

- **A rota:** `/api/school/:inep/payroll/secretaria?date=MM-AAAA`, a folha do
  total da Secretaria do município da escola, só para escola da rede
  municipal. Pública pela mesma decisão da folha por escola (2026-11-09).
- **A página:** a mesma da folha detalhada, com `secretaria=1`, o título
  "total da Secretaria (sem escola)" e o aviso (o SIOPE não diz a unidade;
  pode haver pagamentos parciais).
- **Lista grande:** a Secretaria de Cuiabá tem 13.019 linhas em abril de
  2026 (7 MB de JSON, 0,37 s). Busca pelo nome e 100 linhas por página, para
  qualquer lista com mais de 100. Paginação no servidor fica para depois, se
  o tamanho incomodar.
- **Acessos:** o botão do painel da Secretaria passou a funcionar; o painel
  da escola ganha "Ver a folha do total da Secretaria" quando o município
  tem gente só lá (#567).

## Validação

- **Docker local:** a folha da Secretaria de Cuiabá em abril de 2026 (131
  páginas), o atalho da EMEB Zeferino.
- **Testes:** Perl, 211 arquivos; vitest, 1.461. CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
