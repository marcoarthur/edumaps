# Reavaliação: P2 leva o painel da rede ao conselho e ao prefeito (2026-11-27)

Nona rodada da P2 (secretaria municipal), a pedido do developer. A anterior
(2026-11-27, a folha no conselho do Fundeb) teve o veredito **adotaria, em
piloto numa rede**, e os dois achados viraram issues entregues: QE-01 →
#610 (#612), o painel da rede com toda a folha; QE-02 → #611 (#613), o
bloco "A folha e o Fundeb".

- **Avaliou:** só a P2.
- **Material:** o perfil da rede de Cuiabá (`/municipio/perfil`), o painel
  financeiro de uma escola com folha própria (51171805) e o da rede (pela
  51091194), em 2025 e 2026; a ajuda de financeiro e folha. Telas no
  Chrome, com os dados de demonstração locais.
- **O trabalho que ele faria:** abrir o painel da rede de Cuiabá para
  conferir as respostas novas (o total da rede, a parte do Fundeb, o custo
  do piso) e mandar ao conselho do Fundeb e ao prefeito o link do painel de
  2025, o último ano com a receita publicada.
- ⚠️ Simulação: não substitui um secretário de verdade.

## O que ele fez

1. **O perfil da rede:** a entrada natural de quem cuida da rede,
   "Perfil da Rede · Cuiabá · MT · 382 escolas". Tem docentes, INSE, IDEB e
   SAEB comparados com o Brasil; nada de folha, gasto, Fundeb ou piso, nem
   um link para o painel financeiro da rede.
2. **O painel de uma escola da rede (51171805, com folha própria):** o
   painel é da escola. O cartão "Por fonte de recurso" diz: a conta do
   mínimo legal "usa a receita do Fundeb do município, que só aparece no
   painel da rede". Não há link para esse painel. O atalho "Ver a folha do
   total da Secretaria" abre a lista do mês da Secretaria, não o painel.
3. **Como chegar ao painel da rede:** só abrindo uma escola municipal que
   não aparece na folha do SIOPE. Em Cuiabá, 4 das 171 escolas municipais
   em funcionamento; ele só chegou porque já conhecia a 51091194 da rodada
   anterior. Num município que declara toda escola, não haveria porta
   nenhuma: o total da rede, a parte do Fundeb (77,8% em 2025) e o custo do
   piso (R$ 13,4 mi) ficariam fora da tela.
4. **O link para o conselho:** ele escolhe 2025 no painel da rede (onde está
   a parte do Fundeb) e copia o endereço: `?inep=51091194`, sem o ano. Abre
   o link com `&ano=2025` à mão: a tela abre em 2026, onde a receita ainda
   não saiu e não há a parte paga. O conselheiro veria outro ano e outra
   resposta.

## O que funciona para ele

- Dentro do painel da rede, as respostas da rodada anterior estão certas e
  explicadas: o total declarado (R$ 489,5 mi em 2025), as partes, o motivo
  por ano, a parte do Fundeb (77,8% de R$ 588,0 mi) e, em 2026, o custo do
  piso contra a receita de 2025, com a fonte e a data no rodapé.
- A nota da folha completa diz que a lista é da rede inteira, com o lugar
  de cada pagamento.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QF-01 | bloqueia | **O painel da rede não tem porta.** As respostas que o secretário leva ao conselho e ao prefeito (o total da rede, a parte do Fundeb, o custo do piso, a folha da rede inteira) só aparecem ao abrir uma escola municipal que não está na folha do SIOPE. O perfil da rede não tem a parte financeira nem link para ela, e o painel de uma escola com folha própria remete ao "painel da rede" sem link. Pedido: o painel financeiro da rede municipal aberto pelo município (do perfil da rede e de cada painel de escola da rede), com o mesmo conteúdo do painel da rede de hoje, sem depender de uma escola fora da folha; o painel de uma escola sem folha própria continua levando a ele. | Cuiabá: 4 de 171 escolas municipais abrem o painel da rede; o perfil da rede não cita a folha; o aviso do painel da 51171805 cita o painel da rede sem link | P2, P5, P6 |
| QF-02 | atrapalha | **O link do painel não guarda o ano.** O ano escolhido não vai para o endereço, e o `ano` no endereço não é lido: o link enviado ao conselho abre no ano mais recente. Para o conselho, a pergunta de 2025 (a parte do Fundeb) vira a de 2026 (receita não publicada). Pedido: o ano do painel no endereço, lido ao abrir e atualizado ao trocar. | `?inep=51091194&ano=2025` abre em 2026 | P2, P5, P6 |

Não é achado (cobertura de dados, não da tela): ele quis comparar a parte
do Fundeb de Cuiabá com a de outras redes de MT, mas só Cuiabá tem folha
carregada no estado (Alta Floresta D'Oeste, Taubaté e Ubatuba são de outros
estados). É carga, não produto; volta quando houver folha de outras redes.

Não é achado: o rodapé do painel de uma escola com folha própria cita a
receita do Fundeb como fonte, embora o bloco não apareça nele (o catálogo
lista a fonte pela tela, não pelo bloco). Detalhe, a rever com o QF-01.

## Veredito

**Adotaria, em piloto numa rede** (mantido). As respostas estão certas,
mas escondidas: um secretário que não conheça uma das 4 escolas fora da
folha não acha o painel da rede, e o link que ele mandaria ao conselho abre
no ano errado. O conteúdo está pronto; falta a porta.

## Encaminhamento

Propostas duas issues (só com a aprovação do developer): QF-01 primeiro (a
porta do painel da rede pelo município), depois QF-02 (o ano no endereço),
que vale para o painel da escola e o da rede.

## Andamento
