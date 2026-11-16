# Ciclo 2026-11-16: versão dos dados no CSV do agrupamento

- **Período:** 2026-11-16.
- **História:** #438 (PR #441), achado RV-03 da
  [reavaliação P4/P6](../avaliacoes/2026-11-15-analises-publicas-reavaliacao.md).
- **Avaliação:** sem rodada nova; os vereditos da reavaliação ficam.
- **Engenharia:** nota técnica 206.

## Resumo

- O CSV do agrupamento diz de que base veio: colunas `ano_censo` e
  `ano_ideb` e os anos no nome do arquivo
  (`agrupamento-censo2025-ideb2023-….csv`).
- Arquivos de agrupamentos antigos continuam saindo, com as colunas vazias.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto:** a diretora não exporta
agrupamentos.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:** a
planilha que a equipe técnica guarda diz o ano dos dados sem anotação à mão.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria com ressalvas (mantido). **Resolvido:** RV-03. O
arquivo guardado cita a base sozinho, mesmo depois de a execução vencer.
**Fica:** RV-02 e RV-05 (#439, decisão de produto).

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto indireto:** anexo de
processo com a versão dos dados no próprio arquivo.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** a base da matéria
publicada leva o ano dos dados no nome.

## O que este ciclo ensinou

- A versão que está só na tela some quando o dado sai dela. O que é exportado
  carrega a própria procedência.
