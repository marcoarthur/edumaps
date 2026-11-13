# Especificação de Requisitos — Escolas com entorno parecido (similaridade territorial pelo IVET)

**Data:** 2026-11-13
**Autor:** engenharia de requisitos (agente) com o developer
**Versão:** 0.1 — rascunho; as decisões da seção 2 aguardam o developer
**Issue relacionado:** #138 (reescopada nesta spec)
**Base:**
- a reavaliação da #138 (comentário de 2026-11-13);
- o card do IVET (`analysis/edumapsr/inst/ivet-card.yml`, fórmula `ivet-v1.3`);
- a curadoria do Tech Lead (Z:11766);
- a disciplina de supressão da #129.

---

## 0. Situação

**A #138 foi rebaixada em 2026-09-30.** O argumento era que o IVET só tinha
proxies iguais para todo o município. Assim, "escolas semelhantes" queria
dizer apenas "escolas do mesmo município com entradas parecidas".

**Esse argumento caiu.** A segunda medição nacional (2026-10-19, LXC, 145.732
escolas publicáveis) já traz quatro dos sete blocos variando por escola:

| Bloco | O que mede | Grão | Cobertura |
|---|---|---|---|
| A | a própria escola (6 notas) | escola | 180.540 |
| B | socioeconômico do entorno | setor censitário (área de influência) | 145.718 |
| C | mobilidade | isócrona por escola (Sudeste e Nordeste) + sinistros e frota municipais | 145.734 |
| D | saúde | distância à UBS por escola + oferta municipal | 145.734 |
| E | segurança | município | 180.533 |
| F | meio ambiente | área de influência da escola | 145.734 |
| G | recursos | município | 177.397 |

**Os pré-requisitos estão cumpridos.** As fases de ingestão #125, #126, #127
e #130 e o `pgvector` (#153) estão fechados.

**O título da issue está desatualizado.** A parte "PgVector" já existe e mede
outra coisa (seção 1.3).

## 1. Contexto e objetivo

### 1.1 A lacuna

O produto compara escolas pela **própria escola**: infraestrutura, docentes,
matrículas, IDEB e INSE. Não há como responder:

> "Quais escolas, em qualquer município, têm um **entorno** parecido com o
> meu (renda, saneamento, acesso, saúde, risco ambiental) — e como elas se
> saem?"

É a pergunta de benchmarking justo do gestor (P1): comparar-se com quem
enfrenta o mesmo território. É também a pergunta de política da secretaria
(P2): tratar juntas as escolas de contexto semelhante.

### 1.2 Objetivo

Para cada escola com IVET publicável, listar as escolas de **entorno mais
parecido** e dizer **por que** são parecidas, componente a componente. A
ausência de dado nunca é tratada como zero (#154).

### 1.3 O que já existe (e não muda nesta spec)

| Lente | Onde aparece | Sobre o quê | Como |
|---|---|---|---|
| Similares no município | painel da escola (`similar_schools`) | bloco A: as 6 notas da escola | cosseno no `pgvector` (`analytics.school_embedding`, HNSW), top 3 no município |
| Pares do perfil | perfil da escola ("Escolas similares") | indicadores do Censo, IDEB e INSE | Gower no serviço R (`/similarity/db`, `analytics.similarity_pairs`) |
| Municípios similares | análise da cidade | indicadores municipais | matriz euclidiana (`analytics_municipios_similaridade`) |

Achados à parte, fora do escopo desta spec (vão para uma issue pequena):

- nada no código enfileira `refresh_school_embeddings`, o job que atualiza o
  embedding; depois de um Censo novo ele fica velho até alguém rodá-lo à mão;
- o embedding troca nota ausente por 0 (`COALESCE(…, 0)`). Isso contraria a
  #154, sem efeito hoje porque o bloco A cobre 100% das escolas.

### 1.4 Atores

- **P1 — gestor escolar:** vê as escolas de entorno parecido no perfil da
  escola dele.
- **P2 — secretaria:** numa fase posterior (fora desta spec), agrupa as
  escolas da rede por entorno.
- **P4 — academia:** consumidora indireta, sem exportação nesta spec.

## 2. Decisões a tomar (com recomendação)

**D1 — Quais entradas.**
- **Recomendação:** os **componentes territoriais do default do card**:
  - **B:** analfabetismo, renda e saneamento;
  - **C:** acesso a pé em 15 min e de carro em 45 min, com sinistros e frota;
  - **D:** distância à UBS e cobertura da atenção primária;
  - **E:** homicídio doloso, latrocínio e lesão corporal seguida de morte;
  - **F:** fogo, vegetação nativa e carbono do solo;
  - **G:** Fundeb por aluno, despesa por aluno e autonomia fiscal.
- **O que fica fora:**
  - o bloco A, que já tem a sua lente e responde a outra pergunta;
  - os componentes fora do default, como `preto_pardo`, que exige
    justificativa para publicar.
- **Por que componentes e não os 7 blocos:** a explicação (D5) precisa dizer
  *o que* é parecido. Com 7 números agregados, ela só diria "o bloco B é
  parecido".
- **Consequência:** `analytics.ivet_escola` guarda só os blocos. Os
  componentes saem do `edumapsr` (`ivet_medir_nacional`) e precisam ser
  gravados.

**D2 — Ausência e técnica.**
- **Recomendação: Gower no serviço R**, com pares pré-computados no mesmo
  padrão de `analytics.similarity_pairs`.
  - O Gower aceita ausência nativamente: o componente que falta em uma das
    duas escolas fica fora daquele par.
  - O cosseno do `pgvector` exige o vetor completo. Fora do Sudeste e do
    Nordeste, os acessos do bloco C são NA, e completá-los fere a #154.
- **Regra adicional:** um par só vale se as duas escolas tiverem em comum
  componentes que somem ao menos **70% do peso**. Abaixo disso não há par.

**D3 — Conjunto candidato.**
- **Recomendação:** escolas em funcionamento com IVET publicável, de
  **qualquer município** — é o que esta lente traz de novo.
- **Padrão da consulta:** mesma UF e mesma etapa principal.
- **Filtros opcionais:** dependência (municipal, estadual) e "todo o país".

**D4 — Métrica de avaliação**, declarada antes do código, como a própria
issue exige. Recomendação, três medidas:

1. **Coerência:** a diferença média do IVET entre a escola e os seus 10 pares
   tem de ficar abaixo do p25 da diferença para 10 escolas sorteadas na mesma
   UF.
2. **Estabilidade:** de um snapshot para o seguinte sem mudança de fórmula, os
   10 pares mudam pouco (sobreposição ≥ 0,6).
3. **Validade de face:** 20 pares sorteados lidos pela persona P1 e pelo
   developer. Nenhum par pode ser "absurdo", como escola rural isolada com
   escola de capital.

**D5 — Explicação na tela.**
- **Recomendação:** cada par mostra os **3 componentes mais parecidos** e o
  **mais diferente**, com os valores das duas escolas lado a lado. Também diz
  quantos componentes ficaram de fora por falta de dado.
- **O que não fazer:** mostrar só um "93% similar" sem o porquê.

**D6 — Lugar no produto.**
- **Recomendação:** um bloco novo, "Escolas com entorno parecido", no
  **perfil da escola**, ao lado dos pares atuais.
- As duas lentes existentes continuam como estão.
- A visão da rede (P2) fica para uma fase seguinte.

**D7 — Inferência e LGPD.**
- **Recomendação:**
  - nenhum componente de raça ou cor;
  - a explicação fala do entorno, nunca da população atendida;
  - pares só entre escolas, nada por pessoa.
- **Ponto a decidir:** se a lente é pública (como o IVET da escola) ou fica
  só para gestor logado.
- **Recomendação para o ponto:** pública, como o próprio IVET.

## 3. Requisitos formais (rascunho)

### RF-201: Componentes do IVET gravados por escola

O `edumapsr` grava, por escola e snapshot, os componentes normalizados
(0–1) que entram no IVET. NA continua NA. Critério: para uma amostra, os
componentes reproduzem o bloco gravado em `analytics.ivet_escola`.

### RF-202: Pares de entorno parecido

Um job (fila `analytics`) calcula, por escola publicável, os k = 10 pares mais
próximos pela distância de Gower sobre os componentes da D1. A regra de peso
mínimo da D2 vale para cada par. Os pares são gravados com o snapshot e a
versão da fórmula.

### RF-203: API

A consulta devolve os pares de uma escola com:
- a similaridade;
- os componentes comparados (valor da escola, valor do par e diferença);
- os componentes de fora;
- o snapshot.

Ela aceita os filtros da D3. Sem pares, devolve uma lista vazia com o motivo
(sem IVET publicável ou sem cobertura), nunca um erro mudo.

### RF-204: Bloco no perfil da escola

Lista os pares com a explicação da D5 e um link para o perfil de cada um. A
ajuda diz o que é "entorno", de onde vêm os dados e o que não significa
(não mede a qualidade da escola).

### RF-205: Avaliação registrada

As três medidas da D4 são calculadas por um script do `edumapsr` e registradas
na nota técnica do ciclo. Se a coerência falhar, a lente não é publicada.

## 4. Decomposição arquitetural

- **Banco (Sqitch, changes novas):**
  - `analytics.ivet_componente_escola` (escola, snapshot, componente, valor);
  - uma tabela de pares de entorno, ou o uso de `similarity_pairs` com um
    `tipo`, a decidir pela forma atual dela;
  - GRANT conforme a regra do `edumaps_leitor`: o dado é derivado e público.
- **R (`edumapsr`):**
  - a gravação dos componentes junto de `ivet_refresh()`;
  - a função de pares (Gower com peso mínimo);
  - o script de avaliação;
  - o endpoint no Plumber.
  - O `Collate` do `DESCRIPTION` recebe cada arquivo novo.
- **Backend:** a task Minion que chama o serviço R e a rota de leitura dos
  pares.
- **Frontend:** o bloco do perfil e a ajuda.

## 5. Pré-condições e ordem

1. **Deploy do LXC** (2026-11-16). O banco local não tem o IVET nem as fontes
   territoriais, então a medição real só é possível lá.
2. **#295 concluída** (recarga de ES e MG). Hoje 16.796 escolas estão com o
   acesso sem dado, o que enviesaria os pares nesses dois estados.
3. **Medição no LXC:**
   - cobertura por componente;
   - correlação entre componentes, para não contar duas vezes o mesmo sinal
     (ex.: UBS × cobertura, correlação 0,78);
   - tamanho dos pares × peso mínimo.
4. Só então: issues do sprint e código.

## 6. Riscos e suposições

- **Proxy de grupo social:** entorno parecido tende a ser população
  parecida. A D7 e a explicação pelo entorno são a mitigação; a validade de
  face (D4) é o teste.
- **Viés de fronteira do bloco C:** nas bordas de regiões sem isócrona,
  conforme o card.
- **Blocos municipais (E, G):** todas as escolas do município têm o mesmo
  valor, o que puxa os pares para dentro dele. Pode ser preciso reduzir o
  peso desses blocos; a D4 mede isso.
- **Custo:** k vizinhos para cerca de 145 mil escolas por Gower é viável por
  UF, em lote. O cálculo nacional sem particionar não é.

## 7. Critérios de aceitação globais

- As decisões D1 a D7 estão registradas pelo developer.
- Nenhum componente ausente é tratado como 0, em nenhuma camada (#154).
- Cada par exibido diz por que as escolas são parecidas.
- A avaliação da D4 passa antes da publicação, e os números estão na nota
  técnica.
- As lentes existentes continuam funcionando sem mudança.
