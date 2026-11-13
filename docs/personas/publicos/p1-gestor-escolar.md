# Persona P1: diretora de escola municipal

> Público **P1 — Gestor escolar** do plano de negócios
> (`publicos-alvo.md`). Perfil **e** memória: as avaliações entram em
> "Entradas" (mais recente no topo). Protocolo em [`README.md`](README.md).

## Perfil

- **Quem é:** diretora de uma escola pública municipal de médio porte, com
  coordenação pedagógica e secretaria pequenas. Trabalha com planilha,
  **não programa** e tem pouco tempo de tela entre um problema e outro.
- **Quem paga:** a secretaria, não ela. Ela não escolhe a ferramenta, mas
  decide se vai usá-la. Sem o uso dela, a licença da rede não renova.
- **Perguntas típicas:**
  - "Como está a infraestrutura da minha escola?"
  - "Estou abaixo da média do município?"
  - "Melhoramos no IDEB?"
  - "O que está atrasado no plano de ação e quem é o responsável?"
  - "Como mostro ao conselho e à secretaria o que fizemos?"
- **O que usa:** painel da escola, perfil analítico, pesquisas com a
  comunidade, inventário, documentos e planos, reuniões e atas, equipamentos
  no entorno.
- **O que valoriza:** linguagem do dia a dia, nada de jargão técnico; números
  em que pode confiar diante da secretaria; pouco retrabalho (não digitar duas
  vezes o que já está na plataforma); imprimir para a reunião.
- **O que a faz desistir:** tela técnica demais (o plano de negócios registra
  o bloqueio de saídas com colunas cruas), cadastro que não se corrige depois,
  e número que a coloca mal sem explicar de onde veio.
- **Fonte de leitura:** a gestora escolar do repositório `eduBR` (só leitura)
  é a mesma figura, vista pelo pacote de dados. Aqui a avaliação é do produto.

## Progresso por ciclo

Veredito ao fim de cada ciclo ([fechamentos](ciclos/README.md)):

- [2026-11-12 — planos de gestão](ciclos/2026-11-12-planos-de-gestao.md#p1--gestor-escolar-diretora-de-escola-municipal): adotaria com ressalvas → **adotaria**.
- [2026-11-13 — visão da rede](ciclos/2026-11-13-visao-da-rede.md#p1--gestor-escolar-diretora-de-escola-municipal): adotaria → **adotaria** (mantido).

## Pendências

- Conferir com 2 ou 3 diretoras reais o veredito da reavaliação (adotaria).
- P1-PG-06 e -07 corrigidos no PR #390.
- P1-RD-01 (aviso na tela de que a secretaria lê o plano): #407.
- Conferir com 2 ou 3 diretoras reais se objetivos → metas → ações cobre o
  plano delas (suposição da spec, §6).

## Entradas

### 2026-11-13 — Visão da rede (#375, PRs #399 a #403)

**Material:** ficha, ajuda do gestor e da rede, spec e as telas com os dados
de demonstração. Consolidação em
[`avaliacoes/2026-11-13-visao-da-rede.md`](avaliacoes/2026-11-13-visao-da-rede.md).

**O que mudou para ela:** custo executado e data na ação, previsto ×
executado no relatório, cargo do emissor, sugestão de indicador oficial. A
secretaria da rede lê o plano e o relatório.

**Barreira nova:** P1-RD-01 (incomoda): a tela do plano não avisa que a
secretaria o lê; só a ajuda diz.

**Veredito:** **adotaria** (mantido).

### 2026-11-12 (reavaliação) — Planos de gestão, depois dos PRs #386 a #389

**Material:** as mesmas telas com os dados de demonstração, agora com a
edição, o relatório com custos e o arquivo do plano.

**O que ela tentou fazer:** ligar o PDF do plano, corrigir o prazo da ação
atrasada e revisar a meta do IDEB.

**O que mudou para ela:**

- **P1-PG-01 resolvida.** O ✎ abre o formulário já preenchido no lugar da
  ação; ela mudou o prazo, a ação saiu de "Atrasadas", e a ata e o documento
  continuaram ligados. Era a barreira que a fazia desistir.
- **P1-PG-02 resolvida.** O PDF do plano fica a um clique, na própria página.
- **P1-PG-03 e -05 resolvidas.** O gráfico mostra os anos (2021, 2023) e diz
  qual linha é a base e qual é o alvo; o formulário explica "sentido" e
  "linha de base".
- **P1-PG-04 resolvida.** Os textos saem com os espaços certos.

**Barreiras novas:**

| Id | Gravidade | Barreira | Evidência |
|---|---|---|---|
| P1-PG-06 | detalhe | A unidade "%" sai separada do número: "alvo 12 %". Em português escreve-se "12%". | linha da meta manual |
| P1-PG-07 | detalhe | A legenda do gráfico e a explicação do formulário estão em letra muito pequena (10 a 11 px); numa tela de notebook, ela precisa aproximar. | gráfico da meta, formulário |

**Veredito:** **adotaria.** As ressalvas da primeira avaliação foram
resolvidas, e o que sobrou é acabamento. O passo que falta não é de
software: confirmar com diretoras reais que objetivos → metas → ações
cabe no plano delas.

### 2026-11-12 — Planos de gestão acompanháveis (épico #368)

**Material:** ficha `docs/funcionalidades/gestor/planos-gestao.md`, ajuda
`docs/ajuda/gestor/planos-de-gestao.md`, spec
`docs/specs/2026-11-11-planos-de-gestao.md` e as telas com os dados de
demonstração (lista, plano, relatório).

**O que ela tentou fazer:** abrir o plano de ação do ano, ver o que está
atrasado, registrar uma medição, ligar a ata do conselho como prova e
imprimir o relatório para a reunião.

**O que funciona para ela:**

- **"O que está atrasado" logo no topo**, com prazo e responsável. Responde a
  pergunta da semana sem procurar.
- **"1 de 2 metas medidas" e "Sem medição" em vez de 0%.** É o que a protege
  diante da secretaria: meta não medida não aparece como fracasso.
- **Meta com indicador oficial que se atualiza sozinha**, com a fonte (INEP) e
  o ano. Ela não precisa saber onde buscar o IDEB.
- **Evidência sem reenviar arquivo:** liga a reunião e o documento que já
  estão na plataforma. É o tipo de retrabalho que ela evita.
- **Relatório pronto para imprimir**, com a data de emissão. Serve para o
  conselho escolar.
- **Alerta por e-mail só quando há novidade.** Não vira caixa cheia.

**Barreiras:**

| Id | Gravidade | Barreira | Evidência |
|---|---|---|---|
| P1-PG-01 | **bloqueia** | Não dá para **corrigir** uma ação, uma meta ou um objetivo depois de criados: a ação só muda de situação; prazo, responsável, alvo e descrição não se editam na tela. Para corrigir um prazo, ela teria de excluir a ação e perderia as evidências ligadas. | tela do plano: só o seletor de situação e o ✕; a API já aceita a edição |
| P1-PG-02 | atrapalha | O plano não aponta para o **arquivo** dele (o PDF do PPP em Documentos e planos), embora a ajuda diga que o arquivo "continua em Documentos". Ela fica com duas coisas soltas. | criação do plano sem campo de documento; a API tem `documento_id` |
| P1-PG-03 | atrapalha | O **gráfico da meta** não diz o que são as duas linhas tracejadas nem os anos de cada ponto (só no passar do mouse). | tela do plano, meta do IDEB |
| P1-PG-04 | detalhe | Faltam espaços: "alvo 6pontos (0 a 10)", "prazo 05/03/2026· Coordenação" e, no relatório, "anos iniciais(aumentar, …)". Num papel entregue ao conselho, parece descuido. | tela do plano e relatório |
| P1-PG-05 | detalhe | "Sentido" e "linha de base" são termos de quem faz planejamento; a ajuda explica, mas o formulário não. | formulário de meta |

**Veredito:** **adotaria com ressalvas.** O acompanhamento responde as
perguntas dela e o relatório resolve a prestação de contas. Mas sem poder
corrigir o que cadastrou (P1-PG-01), o primeiro erro de digitação vira
exclusão e retrabalho, e é aí que ela desiste.
