# Reavaliação: P3 procura os concorrentes da unidade (2026-11-23)

Segunda rodada da P3 (rede privada), a pedido do developer. A primeira foi
em 2026-11-14 ([análises públicas](2026-11-14-analises-publicas.md)), com o
veredito **não adotaria** e o bloqueio AN-10 (mercado local, #429). Desde
então, entre outras entregas:

| Entrega | O quê |
|---|---|
| #439 a #530 | base de análise por UF e município, com coordenadas, etapas oferecidas, matrículas por etapa, parceria com o poder público (conveniadas), docência e os seis índices |
| #475, #524 | índices sem zero imposto às privadas (acesso ao cargo e concursados) |
| #527 | perfil da escola privada sem comparação de concursados com as públicas |
| #516, #518 | comparação de redes com creche e pré-escola separadas e as conveniadas |

- **Avaliou:** só a P3.
- **Material:**
  - a base de análise de Franca (SP), blocos Etapas, Matrículas, Parceria,
    Docência, Índices e Porte (253 escolas,
    `base-analise-SP-3516200-censo2025-indices-v7.csv`);
  - a base de SP inteira, para a cobertura das coordenadas;
  - o perfil da escola 35004827 (privada, pré-escola e fundamental), o
    ranking de escolas de Franca e a comparação de redes;
  - para conferir, os campos de endereço do Censo (`clean.censo_escolas`).
- **O trabalho que ele faria:** as duas primeiras perguntas do perfil dele,
  "quais concorrentes estão perto e como se comparam?" e "quantas crianças
  há em volta da unidade e quem as atende?", para uma unidade em Franca.
- ⚠️ Simulação: não substitui um mantenedor de verdade.

## O que ele fez

1. **Baixou a base de Franca** e marcou a unidade (35004827), que oferece
   pré-escola e os anos iniciais e finais.
2. **Listou os concorrentes num raio de 2 km** pela latitude e longitude
   (fórmula de distância numa planilha), filtrando quem oferece pré-escola
   ou anos iniciais:
   - 37 escolas: 24 privadas, 7 municipais e 6 estaduais;
   - para cada uma, as matrículas na pré-escola e nos anos iniciais, se é
     conveniada com a prefeitura (o "Lar Esperança e Fé" é, com 98 na
     pré-escola, oferta gratuita na porta dele) e os índices de
     capacitação docente e de infraestrutura;
   - os índices já não puxam a privada para baixo (`indices-v7`).
3. **Comparou a unidade** pelo perfil da escola:
   - o grupo de referência e as escolas semelhantes são privadas de
     contexto parecido no município, e servem de benchmark;
   - a linha de concursados diz que não se aplica à rede privada.
4. **Sentiu falta de concorrentes conhecidos.** O "Santa Teresa de Jesus
   Colégio" e o "Mundo do Saber Unidade II", que ele sabe que estão perto,
   não apareceram no raio. Também faltavam as duas bilíngues da cidade (The
   Joy School e Maple Bear), o segmento premium que ele mais acompanha.
   - Essas escolas estão na base, mas **sem latitude e longitude**.
   - Em Franca, 16 das 136 privadas não têm coordenada (contra 1 municipal
     e 1 estadual).
   - Em SP, **23,3% das privadas** não têm coordenada, contra 1,1% das
     estaduais e 6,9% das municipais.
   - O Censo traz o CEP, o bairro e o endereço de todas elas, mas a base
     não os entrega. Sem a coordenada, ele não tem como situar o
     concorrente.
5. **Procurou a demanda.** A população por idade no entorno continua só no
   painel do gestor (com login). Na base há só a população do município,
   sem faixa etária. A pergunta "quantas crianças há em volta?" segue sem
   resposta (AN-10, #429).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P3 | não adotaria | **não adotaria** (mantido), **mais perto** | a base pública já dá a lista de concorrentes com etapas, matrículas, conveniadas e índices justos com a privada, e o perfil serve de benchmark; mas a demanda do entorno não existe (AN-10, #429), a distância exige planilha, e um em cada quatro concorrentes privados não tem coordenada (QR-01) |

O que o faria adotar: a leitura de mercado local da #429 (decisão de
produto pendente). A QR-01 é o passo pequeno que já melhora a lista de
concorrentes de quem usa a base.

## O que funciona

- **Concorrentes com dados comparáveis:** etapas, matrículas por etapa,
  conveniadas e índices na mesma linha.
- **Índices justos com a privada:** sem o 0 do acesso ao cargo nem o dos
  concursados (#475, #524).
- **Perfil da escola privada** com benchmark entre privadas e sem
  comparação que não se aplica (#527).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QR-01 | atrapalha | **Um quarto das privadas sem coordenada, e a base sem o endereço.** O Censo traz o CEP, o bairro e o endereço de todas as escolas, mas a base só entrega a latitude e a longitude, que faltam em 23% das privadas de SP. Pedido: `cep` e `bairro` (e, se fizer sentido, o endereço) na identificação; e, no dicionário e na ajuda, a cobertura das coordenadas por rede e como usar o CEP ou o bairro quando a coordenada falta. | SP: sem coordenada 23,3% das privadas, 6,9% das municipais e 1,1% das estaduais. Franca: 16 de 136 privadas, entre elas as duas bilíngues (The Joy e Maple Bear); CEP presente em todas | P3, P6 |

Continua aberto: AN-10 (#429, mercado local), agora com a evidência desta
rodada.

## Encaminhamento

Aguarda a decisão do developer sobre abrir a issue (QR-01) e comentar a
#429 com a evidência desta rodada.
