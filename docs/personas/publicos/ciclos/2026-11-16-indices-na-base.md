# Ciclo 2026-11-16: índices do EduMaps na base de análise

- **Período:** 2026-11-16 e 2026-11-17.
- **História:** #465 (PR #466), achados RY-01 e RY-02 da
  [sexta avaliação da P4](../avaliacoes/2026-11-16-p4-versao-e-selecao.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 218.

## Resumo

- A base de análise ganhou o bloco "Índices do EduMaps": os seis índices de
  0 a 10 de cada escola da UF, com a coluna `versao_indice`. O dicionário traz
  o método de cada índice. O nome do arquivo e a tela trazem a versão
  (`indices-v2`).
- O CSV do ranking de escolas leva a versão do índice no nome do arquivo.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto:** a diretora olha a
própria escola no perfil e no ranking do município, não na base da UF.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:** a
equipe técnica baixa os índices de todas as escolas da rede num arquivo só,
com o filtro de rede, em vez de um índice por vez.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido:** RY-01 e RY-02. Os índices
entram no mesmo arquivo do IDEB, do INSE e das etapas, com a versão no nome e
na linha. Antes eram 417 downloads para a BA. **Ficam** da sexta avaliação:
nenhum achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
conselho estadual cruza os índices de todas as escolas da UF num arquivo
citável.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** uma matéria estadual
sobre a infraestrutura ou a diversidade das escolas parte de um único CSV,
com a versão do índice no nome do arquivo.

## O que este ciclo ensinou

- Um índice que só sai uma tela por vez não serve para a pesquisa, por mais
  bem documentado que seja. A versão citável (#462) só rendeu quando o índice
  chegou ao arquivo que a pesquisadora já usa.
- Ligar a MV pelo ano do Censo da base, e não só pela escola, troca um erro
  silencioso (o índice de um ano ao lado do Censo de outro) por uma coluna
  vazia, que o dicionário explica.
