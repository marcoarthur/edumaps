# Ciclo 2026-11-19: versão citável dos índices coerente nos textos

- **Período:** 2026-11-19.
- **História:** #501 (PR #502), achados RE-01 e RE-02 da
  [vigésima quarta avaliação da P4](../avaliacoes/2026-11-19-p4-citar-indices.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 236.

## Resumo

- A **versão citável dos índices do EduMaps** (`indices-v6`) passa a ser a
  mesma em `/fontes`, no CSV, nas ajudas e na fórmula completa, e um teste
  impede que a próxima mudança de fórmula esqueça algum texto.
- A ajuda de fontes passa a dizer que os arquivos da carga, com o SHA-256,
  só aparecem quando a carga os registra (hoje, nenhuma base pública).

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto:** a diretora não cita a
versão da fórmula.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Sem impacto
relevante:** relatórios da secretaria citam a fonte, raramente a versão.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto.**

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido:** RE-01 e RE-02. Nenhum achado
aberto da vigésima quarta avaliação.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** a versão
citada num parecer é a mesma em todo lugar.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** quem cita o índice
cita a versão certa.

## O que este ciclo ensinou

- Um teste de versão que confere só o código deixa os textos para trás. O do
  IVET já conferia os quatro lugares; o dos índices passou a conferir os
  textos também.
