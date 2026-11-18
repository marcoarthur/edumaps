# Ciclo 2026-11-18: escolas semelhantes pela distância entre as notas

- **Período:** 2026-11-18.
- **História:** #487 (PR #488), achados RL-01 e RL-02 da
  [décima sétima avaliação da P4](../avaliacoes/2026-11-18-p4-escolas-semelhantes.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 229.

## Resumo

- As escolas semelhantes do painel da escola passam a ser as de **notas
  mais próximas, nota a nota**. Antes, o critério (cosseno) juntava escolas
  de mesmo "formato" de notas em patamares diferentes.
- O cartão mostra a distância em pontos e as seis notas da vizinha ao lado
  das da escola.
- A ajuda diz o critério de cada um dos três lugares com escolas
  semelhantes.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto direto:** a escola sugerida
para trocar experiências é de fato do mesmo patamar, e o cartão mostra em
que nota ela está à frente.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:**
os pares sugeridos às escolas da rede ficam comparáveis.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora também com as escolas semelhantes.
**Resolvido:** RL-01 e RL-02. **Ficam** da décima sétima avaliação: nenhum
achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Sem impacto:** não usa as
escolas semelhantes do painel.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** "escolas parecidas,
resultados diferentes" passa a comparar escolas do mesmo patamar.

## O que este ciclo ensinou

- O cosseno é a métrica padrão de embeddings, mas aqui o vetor não é um
  embedding: são notas na mesma escala, e o nível importa.
- O sinal estava no próprio código: a #421 tirou o número do cartão porque
  as distâncias saíam todas "0.00".
