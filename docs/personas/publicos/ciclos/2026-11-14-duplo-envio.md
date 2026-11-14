# Ciclo 2026-11-14: botão de salvar sem réplica

- **Período:** 2026-11-14. Achado e merge no mesmo dia.
- **História:** achado do developer no teste local; sem issue. PR #415.
- **Avaliação:** não houve rodada das personas. É uma correção de
  capacidades existentes.
- **Engenharia:** nota técnica 197.

## Resumo

Ao salvar uma meta, uma ação ou outro registro, o botão fica desabilitado e
mostra "Salvando…" até a confirmação. Um clique a mais não cria mais uma cópia
do que foi salvo.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**O que mudou para ela:** metas, ações, objetivos e medições do plano não se
duplicam com um clique a mais. O mesmo vale para inventário, relações,
contatos, listas, documentos, reuniões e a publicação de pesquisas. Antes,
uma réplica no plano distorcia o "N de M" do andamento e exigia apagar à mão.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido; sem nova avaliação).

**O que mudou para ela:** o "Novo convite" das contas da rede não gera mais
dois convites, o que invalidava o primeiro link. Os planos que a rede lê não
chegam com metas duplicadas.

## P3 — Rede privada (mantenedor)

**Sem impacto direto neste ciclo.** As telas do gestor são as mesmas para a
escola privada e a correção vale para ela; nada novo para o mantenedor.

## P4 — Academia (pesquisadora)

**Sem impacto direto neste ciclo.**

## P5 — Órgãos de controle e conselhos

**Sem impacto direto neste ciclo.** Indireto: um plano sem réplicas é um
registro mais fiel do que a escola planejou.

## P6 — Terceiro setor e jornalismo de dados

**Sem impacto direto neste ciclo.**

## O que este ciclo ensinou

- Um erro achado numa tela costuma ser um padrão. A varredura dos botões
  (85, só 26 com trava) mostrou o tamanho antes de corrigir.
- A trava tem de valer antes do redesenho. Só o `disabled` deixa uma janela;
  o guarda síncrono fecha essa janela, e o teste prova com o POST contado.
