# Ciclo 2026-11-14: envio sem duplicidade também no servidor

- **Período:** 2026-11-14. Issue, merge e fechamento no mesmo dia.
- **História:** #416 (complemento do PR #415). PR #417.
- **Avaliação:** não houve rodada das personas. É uma correção de
  capacidades existentes.
- **Engenharia:** nota técnica 198.

## Resumo

Se a conexão cair depois de salvar e a pessoa tentar de novo, o sistema
reconhece o envio e devolve o registro já criado, em vez de uma cópia. Se ela
tiver mudado os dados entre as tentativas, o sistema avisa e pede para
recarregar a página. Nova capacidade descrita em "Envio sem duplicidade".

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**O que mudou para ela:** numa escola com internet instável, a nova tentativa
de salvar uma meta, ação ou contato não cria mais uma cópia. O que não muda:
com o plano aberto em duas abas, cada aba ainda salva por conta própria.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido; sem nova avaliação).

**O que mudou para ela:** a mesma proteção vale para as contas da rede, e os
planos que a rede lê ficam livres de réplicas por falha de conexão.

## P3 — Rede privada (mantenedor)

**Sem impacto direto neste ciclo.** As telas do gestor são as mesmas para a
escola privada; nada novo para o mantenedor.

## P4 — Academia (pesquisadora)

**Sem impacto direto neste ciclo.**

## P5 — Órgãos de controle e conselhos

**Sem impacto direto neste ciclo.** Indireto: registros sem cópia acidental
são um retrato mais fiel do que a escola planejou.

## P6 — Terceiro setor e jornalismo de dados

**Sem impacto direto neste ciclo.**

## O que este ciclo ensinou

- Escolher a proteção pelo caso que sobra. Depois do #415, o que sobrava era
  a nova tentativa após tempo esgotado; a chave cobre esse caso e diz com
  clareza o que não cobre (duas abas).
- Uma trava no servidor não pode devolver, calada, a resposta de outro envio.
  Por isso a mesma chave com outros dados dá erro, em vez de replay.
