# Reavaliação: P2 planeja a expansão da creche (2026-11-23)

Segunda rodada da P2 (secretaria municipal) no dia, a pedido do developer.
A primeira (prestação de contas ao conselho, em Franca) teve o veredito
**adotaria, em piloto**, e o achado QP-01 (taxa de atendimento) virou a
#533. Desde então:

| Entrega | O quê |
|---|---|
| #533 | população por idade do Censo 2022 e taxa de atendimento na comparação de redes e na base |
| #535, #539 | taxa no ranking de redes, com a meta, o CSV e as fontes certas |
| #541, #542 | posição da escola sem verde fixo e sinais de atenção com os números |
| #545 | o DF com a rede distrital e as conveniadas com o governo distrital |

- **Avaliou:** só a P2.
- **Material:**
  - a comparação de redes e o quadro da taxa de atendimento de Vitória de
    Santo Antão (PE, 144 mil habitantes, 56 escolas municipais);
  - o ranking da creche no Nordeste, nos municípios de 100 a 500 mil
    habitantes;
  - a base de análise da rede municipal (blocos Etapas, Matrículas,
    Infraestrutura e Porte).
- **O trabalho que ele faria:** o secretário escreve a meta 1 do plano
  municipal de educação: quanto falta de creche e de pré-escola, quantas
  vagas abrir até o fim do plano e onde abrir.
- ⚠️ Simulação: não substitui um secretário de verdade.

## O que ele fez

1. **Onde o município está:** no ranking da creche entre os municípios do
   Nordeste com 100 a 500 mil habitantes, Vitória de Santo Antão tem
   19,1% (todas as redes). Está entre os mais longe da meta, junto de
   outras cidades da região metropolitana do Recife.
2. **O quadro da comparação de redes:**

   | Etapa | Crianças | Todas as redes | Rede municipal | Meta |
   |---|---|---|---|---|
   | Creche (0 a 3) | 6.550 | 19,1% | 6,3% | 50% |
   | Pré-escola (4 e 5) | 3.642 | 86,4% | 48,5% | 100% |

   A rede municipal tem 412 matrículas em creche, em só 5 das 56 escolas,
   cada uma num bairro. As privadas têm 837, nenhuma
   conveniada.
3. **Quantas vagas abrir:** o plano municipal, o orçamento e o pedido de
   recursos (Proinfância) são escritos em **vagas**, não em porcentagem. A
   tela não dá esse número, e ele faz a conta à mão a partir das crianças
   e da taxa:
   - creche: 50% de 6.550 = 3.275; hoje são 1.249 em todas as redes;
     **faltam cerca de 2.026 vagas**;
   - pré-escola: 3.642 crianças; hoje são 3.148; **faltam cerca de 494**.

   A conta é simples, mas é a que ele leva à prefeitura. Errar na mão (ou
   usar a taxa da rede municipal em vez de todas as redes) muda o pedido
   em centenas de vagas.
4. **Onde abrir:** ele quer saber em que bairros estão as crianças sem
   creche. A base dá o bairro e o endereço de cada escola (#531), mas as
   crianças só existem por município: a população por idade dos setores
   censitários (tabela `clean.censo2022_setor`, com `idade_0_4`) não tem
   carga para PE no banco. Sem isso, "onde abrir" fica para o mapa da própria
   secretaria.

## O que funciona para ele

- A taxa do município com as três contas e a meta, com a fonte e o ano.
- A posição entre os municípios parecidos, no ranking da creche.
- A base com as escolas que oferecem creche, o bairro e o endereço de
  cada uma.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QK-01 | atrapalha | **A taxa não diz quantas vagas faltam.** O plano municipal e o orçamento pedem o número de vagas para chegar à meta, e a tela só dá a porcentagem. Pedido: no quadro da comparação de redes e no CSV do ranking, as **vagas que faltam para a meta** (meta × crianças − matrículas de todas as redes; zero quando a meta foi atingida), com o aviso de que a população é de 2022. | Vitória de Santo Antão: creche 19,1% de 6.550 crianças (faltam cerca de 2.026 vagas); pré-escola 86,4% de 3.642 (faltam cerca de 494); `/municipio/compare?codigo_ibge=2616407` | P2, P5, P6 |

Observação, sem pedido por ora: "onde abrir vagas" pede as crianças de 0
a 3 anos por setor censitário ou bairro. A tabela de setores do Censo
2022 existe no banco, com a faixa de 0 a 4 anos, mas não tem carga para
PE no banco. Carregar exige baixar os dados do IBGE e depende da
permissão do developer.

## Veredito

**Adotaria, em piloto numa rede** (mantido). O diagnóstico da meta 1 sai
da plataforma, com fonte. O número que vai para o plano e o orçamento
(QK-01) e a localização da demanda ainda saem da conta e do mapa dele.

## Encaminhamento

Issue **#547** (QK-01), aberta com a aprovação do developer.

## Andamento

- 2026-11-23: #547 (PR #548) mergeado: QK-01 resolvido.
  - A comparação de redes diz as vagas que faltam (Vitória de Santo
    Antão: 2.026 de creche e 494 de pré-escola).
  - O ranking dá a soma do recorte (Nordeste: 405.893 de creche) e o CSV
    traz `vagas_faltam_meta`.
- "Onde abrir" segue pendente da carga dos setores do Censo 2022.
