# Reavaliação: P4 depois dos índices do EduMaps na base de análise (2026-11-17)

Sétima rodada da P4 (academia), depois da entrega da sexta rodada:

| Entrega | O quê |
|---|---|
| #466 | bloco "Índices do EduMaps" na base, com `versao_indice` e a versão no nome do arquivo (RY-01); versão no nome do CSV do ranking de escolas (RY-02) |

- **Avaliou:** só a P4, a pedido do developer.
- **Material:**
  - as ajudas `base-de-analise.md` e `rankings.md`, e o dicionário da base;
  - a API do ranking de escolas;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ela faria:** baixar a BA e o ES com todos os blocos,
    pôr os índices do EduMaps no modelo do IDEB e comparar as redes
    municipais pela formação docente.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A base com os índices** (RY-01 resolvido).
   - A BA e o ES, com todos os blocos, juntam com `rbind`: 19.152 escolas e
     62 colunas.
   - Os arquivos trazem a versão no nome:
     `base-analise-BA-censo2025-ideb2023-inse2023-indices-v2.csv`.
   - Toda linha tem `indices-v2` em `versao_indice`, e nenhum índice está
     vazio.
   - O dicionário traz o método de cada índice e o link para a seção dos
     índices na ajuda.
2. **Conferiu com o ranking.** Para as 1.432 escolas de Salvador, a
   capacitação docente da base é igual à do ranking de escolas. A soma da
   ajuda para a infraestrutura básica dá o mesmo número do ranking nas
   1.432 escolas.
3. **Pôs os índices no modelo do IDEB** (anos iniciais; 4.155 escolas; com
   rede, localização, UF e INSE).
   - A infraestrutura básica (0 a 4) segue sem associação (p = 0,45).
   - O índice de infraestrutura entra com 0,084 ponto de IDEB por ponto do
     índice (p < 0,001), R² 0,377. Ele mede o que a contagem básica não
     mede: salas, laboratórios, acessibilidade e tecnologia.
   - A capacitação docente não se associa (p = 0,56); a capacidade gestora
     fica no limite (p = 0,06).
   - Para ela, este é o primeiro resultado que só o EduMaps dá: o índice
     pronto, citável e na mesma base do IDEB e do INSE.
4. **Comparou as redes municipais pela formação docente.**
   - Fez a média da capacitação docente por município e estranhou os
     zeros: 753 escolas com 0.
   - **312 delas não têm docente nem matrícula registrados no Censo.**
     Todas têm as sete colunas `oferece_*` em 0: são centros de atendimento
     educacional especializado, instituições de apoio e outras escolas sem
     turma regular. A diversidade discente delas também é 0, e a capacidade
     de atendimento fica perto de zero (média 1,77).
   - A ajuda da base diz "Ausência é célula vazia, nunca zero". A ajuda dos
     rankings diz o contrário para os índices: "a escola sem o registro fica
     com 0". O dicionário diz "Escola sem registro de docentes no Censo fica
     com 0".
   - **Efeito na conta dela:**
     - essas escolas estão em 237 municípios;
     - em Divino de São Lourenço (ES), a média da capacitação docente é 5,93
       com elas e 7,91 sem elas;
     - num ranking das 495 redes municipais pela média, 206 mudam 10
       posições ou mais quando elas saem.
   - No ranking de escolas, elas aparecem no fim com 0. Salvador tem 28
     zeros, e as últimas são instituições de atendimento a crianças com
     deficiência. Ali o 0 lê como "a pior formação docente da cidade".
   - Ela contornou filtrando as escolas sem nenhuma etapa oferecida, mas só
     porque desconfiou dos zeros (RZ-01).
5. **O dicionário da infraestrutura.** A descrição de
   `indice_infraestrutura` manda usar a "Infraestrutura básica" para água,
   energia, esgoto e banheiro. Mas essa coluna não existe na base: a soma
   está só na ajuda. E a fonte aparece como "Índices do EduMaps (EduMaps)"
   (RZ-02).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido) | os índices entram no arquivo da UF com a versão, batem com o ranking e dão um resultado novo no modelo do IDEB; mas o 0 dos índices mistura "sem registro" com nota baixa, ao contrário da regra da própria base (RZ-01) |

## O que funciona

- **Um arquivo só:** IDEB, INSE, etapas, itens do Censo e os seis índices,
  com a versão no nome e na linha.
- **Reprodutível:** a base bate com o ranking escola a escola, e a soma da
  ajuda reproduz a infraestrutura básica.
- **O método está no dicionário**, ao lado da coluna.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RZ-01 | atrapalha | **Escola sem registro no Censo fica com índice 0, não vazio.** São 312 escolas na BA e no ES, sem docente nem matrícula e sem nenhuma etapa oferecida (centros de atendimento especializado, instituições de apoio). Ficam com 0 na capacitação docente e na diversidade discente, contra a regra "ausência é célula vazia" da base. Esse 0 baixa médias municipais em até 2 pontos e as põe no fim do ranking de escolas. Pedido: vazio quando falta o registro, na base e no ranking (o ranking deixaria a escola de fora), com a versão subindo para `indices-v3`, porque muda o valor da MV. | 312 escolas; Divino de São Lourenço 5,93 → 7,91; 206 de 495 redes mudam ≥ 10 posições; Salvador com 28 zeros no fim do ranking; ajuda dos rankings ("fica com 0") contra a da base ("nunca zero") | P4, P6, P1 |
| RZ-02 | detalhe | **O dicionário de `indice_infraestrutura` aponta para uma coluna que a base não tem** ("use Infraestrutura básica"). A fonte aparece repetida: "Índices do EduMaps (EduMaps)". Pedido: na base, apontar os itens `in_*_inexistente` e a soma da ajuda; e mostrar a fonte só como "Índices do EduMaps". | dicionário da base com o bloco `indices` | P4 |

## Encaminhamento

Issue aberta com a aprovação do developer (2026-11-17): **#467** (RZ-01 e
RZ-02 juntas). Decisão: **opção A** (vazio na MV, `indices-v3`).

### Proposta

1. **RZ-01:** decisão de produto antes do código.
   - **Opção A (a que ela pede):** `NULL` no índice quando falta o registro
     (docentes, matrículas, gestores), na MV. Muda a fórmula e sobe a versão
     para `indices-v3`. Também muda o ranking de escolas, que deixa essas
     escolas de fora, e os agregados que usam a MV. O texto do `%METODO` e
     das duas ajudas passa a dizer "fica vazio".
   - **Opção B:** a MV fica como está. A base e o ranking trocam o 0 por
     vazio só onde falta o registro. Não muda a versão, mas a base deixa de
     bater com a MV.
   - A pesquisadora prefere a A: o número citado e o arquivo dizem a mesma
     coisa.
2. **RZ-02:** texto do dicionário. Pode ir no mesmo PR da RZ-01.
