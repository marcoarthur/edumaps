# Ciclo 2026-11-18: grupo de referência do perfil pelo contexto

- **Período:** 2026-11-18.
- **História:** #493 (PR #494), achados RI-01, RI-02 e RI-03 da
  [vigésima avaliação da P4](../avaliacoes/2026-11-18-p4-grupo-referencia.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 232.

## Resumo

- O **grupo de referência** do perfil da escola, a régua dos sinais de
  atenção, passa a ser formado pelas **30 escolas do município de contexto
  mais parecido**: rede, localização, porte, etapas oferecidas e INSE.
- Antes, o grupo saía de um agrupamento sobre os próprios indicadores
  comparados, inclusive o IDEB. A escola de IDEB baixo ficava entre escolas
  de IDEB baixo: em Salvador, a correlação entre o IDEB da escola e a mediana
  do grupo era 0,83. Agora é 0,30.
- O **INSE** deixa de ser sinal de atenção (13 de 38 escolas tinham o
  sinal), e o **N** de cada indicador é o de escolas com o dado.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto direto:** o sinal de atenção no
IDEB compara a escola com escolas de contexto parecido, e não com escolas de
IDEB parecido; some o "INSE pior que o grupo", que não era algo a agir.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:** as
escolas da rede abaixo do grupo no IDEB passam a aparecer; antes o grupo as
escondia.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Impacto pequeno:** a escola privada é
comparada com escolas privadas parecidas do município (#429 segue).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora também com o grupo de referência.
**Resolvido:** RI-01, RI-02 e RI-03. **Fica:** as escolas similares do Perfil
ainda usam o IDEB e só as primeiras 300 escolas do município (fora do
escopo, registrado na ajuda).

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** o sinal
de atenção passa a ser uma régua defensável.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** "escolas parecidas,
resultados diferentes" ganha um grupo que não é escolhido pelo resultado.

## O que este ciclo ensinou

- Uma régua não pode ser feita com o que ela mede. O agrupamento usava os
  indicadores disponíveis da escola, e o IDEB estava entre eles.
- Dois caminhos levavam ao mesmo erro: o k-means de fallback e o grupo do
  último agrupamento rodado, que podia ser o "por desempenho".
