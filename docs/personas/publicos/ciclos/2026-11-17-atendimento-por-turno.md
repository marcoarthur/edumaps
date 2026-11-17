# Ciclo 2026-11-17: lotação por sala e por turno no índice de atendimento

- **Período:** 2026-11-17.
- **História:** #473 (PR #474), achados RS-01 e RS-02 da
  [décima avaliação da P4](../avaliacoes/2026-11-17-p4-oferta-e-turnos.md).
- **Modo:** autônomo (delegação do developer por 4 horas), com aviso pelo
  Telegram.
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 222.

## Resumo

- O índice de capacidade de atendimento passa a medir a lotação das salas
  **por turno**. A escola de dois ou três turnos deixa de parecer lotada.
- **Versões:** `indices-v5` e `ivet-v1.7`.
- **Base:** traz as partes do índice, que o refazem.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto direto:** a escola de dois
turnos, maioria na rede municipal, deixa de aparecer com a nota de lotação
zerada sem ter salas cheias.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:** a
rede de uma cidade grande deixa de parecer que atende pior só por usar as
salas em mais turnos. A diferença entre os portes cai de 1,06 para 0,63
ponto.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora também com o índice de atendimento.
**Resolvido:** RS-01 e RS-02. A pergunta "porte semelhante, oferta
parecida?" se responde sem o artefato dos turnos, e as partes refazem o
índice. **Ficam** da décima avaliação: nenhum achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
parecer sobre falta de vagas não confunde mais o segundo turno com
superlotação.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** a matéria "escolas
superlotadas" deixa de listar escolas que só funcionam em dois turnos.

## O que este ciclo ensinou

- Um índice "por sala" precisa dizer **em que momento**. A sala é usada
  por turno, e a conta que ignora isso mede a organização da escola, não
  a lotação.
- O verify de um defeito antigo deve procurar a assinatura do defeito
  (`qt_mat_bas_d`), não proibir uma coluna que um uso correto pode
  precisar.
