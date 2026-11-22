# Reavaliação: P4 compara o perfil docente entre regiões (2026-11-22)

Trigésima quarta rodada da P4 (academia), a pedido do developer, depois da
entrega da trigésima terceira rodada:

| Entrega | O quê |
|---|---|
| #521 | soma das conveniadas dita como teto e código R completo da oferta de creche na ajuda da base (QV-01, QV-02) |

- **Avaliou:** só a P4.
- **Material:**
  - a base de análise de cinco UFs, uma por região (PA, BA, SP, RS e GO),
    redes municipal e estadual, blocos "Docência", "Matrículas" e "Porte"
    (dez arquivos, 52.794 escolas);
  - o dicionário do bloco Docência e a ajuda da base;
  - o R do host (`read.csv2`, `rbind` das dez bases pela coluna `regiao`);
  - o dicionário de variáveis do INEP versionado no repositório
    (`data_pipeline/dicionarios/censo_inep_variaveis.csv`), para conferir
    a origem das colunas;
  - os textos do perfil da escola e do perfil da rede (código e ajuda).
- **O trabalho que ela faria:** a terceira pergunta do perfil dela, "como o
  perfil docente muda entre regiões?": formação (superior, licenciatura,
  pós-graduação, mestrado), vínculo (concursados) e formação continuada,
  nas redes municipal e estadual, ponderando pelo número de docentes.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Juntou as dez bases.** A coluna `regiao` permite o `rbind` sem
   tabela auxiliar. 719 escolas sem docentes vêm vazias, não 0.
2. **Ponderou pelos docentes** (`qt_docentes`), como a ajuda sugere ao
   dizer que as proporções são sobre o total da escola. O dicionário avisa
   que quem dá aula em duas escolas conta nas duas.
3. **Montou a tabela por região.** Nas redes estaduais, por exemplo:

   | Região (UF) | Superior | Pós-graduação | Concursados | "Sem especialização" |
   |---|---|---|---|---|
   | Norte (PA) | 98% | 71% | 73% | 53% |
   | Nordeste (BA) | 95% | 88% | 97% | 49% |
   | Sudeste (SP) | 97% | 32% | 44% | **91%** |
   | Sul (RS) | 95% | 49% | 31% | 64% |
   | Centro-Oeste (GO) | 99% | 78% | 64% | 66% |

4. **Estranhou a rede estadual de SP:** 32% com pós-graduação e 91% "sem
   especialização". No Brasil, especialização é a pós-graduação lato
   sensu, e as duas colunas deveriam somar perto de 1, nunca mais.
   - Em 56% das 52.075 escolas com docentes, `prop_pos_graduacao` +
     `prop_sem_especializacao` passa de 1, e chega a 2.
   - A correlação de postos de "sem especialização" (invertida) é de 0,38
     com a pós-graduação e de **0,93** com a formação continuada.
5. **Foi à origem.** A coluna vem de `qt_doc_bas_espec_nenhum`, que o
   dicionário do INEP descreve como docentes com "Outros cursos — Formação
   Continuada com no mínimo 80 horas — Nenhum". Mede **quem não fez
   formação continuada**, não quem não tem especialização.
   - O mesmo rótulo, "Docentes sem especialização", aparece no perfil da
     escola e no perfil da rede (comparação com o Brasil e sinais de
     atenção), no agrupamento por perfil docente e nas ajudas do perfil da
     escola e da base.
   - A tabela dela diria que 91% dos professores da rede estadual de SP
     não têm pós-graduação. O que o Censo diz é que 91% não declararam
     formação continuada de 80 horas ou mais.
6. **Viu duas medidas de formação continuada.** `prop_formacao_continuada`
   soma os cursos de formação continuada e divide pelos docentes (limite
   1); 1 − `prop_sem_especializacao` é a proporção de docentes com ao menos
   um curso. Na rede estadual de SP dão 15,5% e 9,5%. O dicionário não diz
   que uma conta cursos e a outra conta pessoas.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), com ressalva no perfil docente | a base junta as regiões e dá o perfil docente ponderado; uma coluna de formação tem o nome e o rótulo errados em toda a plataforma (QU-01), e as duas medidas de formação continuada não se explicam (QU-02) |

## O que funciona

- **A coluna `regiao`** junta as bases de várias UFs sem tabela auxiliar.
- **O dicionário** diz o denominador de cada proporção, o limite a 1 e a
  contagem dupla de quem dá aula em duas escolas.
- **Vazio não é 0:** escolas sem docentes ficam com a célula vazia.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QU-01 | atrapalha | **"Docentes sem especialização" mede quem não fez formação continuada.** A coluna vem de `qt_doc_bas_espec_nenhum` (INEP: formação continuada com no mínimo 80 horas, "Nenhum"), mas o nome, o dicionário e os rótulos dizem "especialização", que no Brasil é a pós-graduação lato sensu. Pedido: rótulo e descrição corretos ("docentes sem formação continuada de 80 horas ou mais") na base, no dicionário, no perfil da escola, no perfil da rede, no agrupamento e nas ajudas, e um nome de coluna que não engane, dizendo o que acontece com o nome antigo. | Em 56% das escolas, pós-graduação + "sem especialização" passa de 1; correlação de postos de 0,93 com a formação continuada e 0,38 com a pós. Rede estadual de SP: 32% com pós e 91% "sem especialização" | P4, P1, P2, P6 |
| QU-02 | detalhe | **Duas medidas de formação continuada sem a relação dita.** `prop_formacao_continuada` soma cursos (uma pessoa com dois cursos conta duas vezes, limite 1); a proporção de docentes com ao menos um curso é 1 menos a coluna de QU-01. Pedido: no dicionário e na ajuda, dizer que uma conta cursos e a outra conta pessoas, e qual usar para "quantos professores fizeram formação continuada". | Rede estadual de SP: 15,5% pela soma de cursos e 9,5% de docentes com ao menos um curso | P4 |

## Encaminhamento

Issue **#522** (QU-01 e QU-02), aberta com a aprovação do developer.

## Andamento

- 2026-11-22: #522 (PR #523) mergeado: QU-01 e QU-02 resolvidos.
  - A coluna da base passou a `prop_sem_formacao_continuada` (o nome antigo
    sai, e o dicionário e a ajuda o citam). O rótulo "Docentes sem formação
    continuada" está no perfil da escola e da rede, nos sinais e no
    agrupamento; a versão do cache dos perfis subiu.
  - Os comentários do banco das 19 colunas `qt_doc_bas_espec_*` dizem
    formação continuada (change `docentes_formacao_continuada_rotulos`).
  - O dicionário e a ajuda dizem que `prop_formacao_continuada` conta
    cursos e que 1 − `prop_sem_formacao_continuada` conta professores.
