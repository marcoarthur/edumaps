# Reavaliação: P3 compara o salário da rede municipal (2026-11-24)

Quarta rodada da P3 (rede privada), a pedido do developer. A anterior
(2026-11-23, onde abrir uma unidade de educação infantil) teve o veredito
**adotaria, em piloto, para escolher a cidade**; a barreira do bairro é a
#429 (setores do Censo 2022), ainda aberta. Desde então, na folha
municipal: o salário base e o piso (#563), o gasto dos meses completos
(#561), a data da carga (#564) e os docentes do Censo ao lado da folha
(#567).

- **Avaliou:** só a P3.
- **Material:** a base de análise das redes municipais de Ubatuba e
  Taubaté (SP; bloco Remuneração, folha de 2026), o painel financeiro de
  uma escola de cada, `/fontes` e as ajudas da base e de financeiro e folha.
- **O trabalho que ele faria:** o diretor do grupo de 8 unidades no
  interior de SP vai abrir uma escola no Vale do Paraíba e precisa definir
  o salário dos professores: quanto paga a prefeitura, para não perder
  professores para o concurso municipal.
- ⚠️ Simulação: não substitui um mantenedor de verdade.

## O que ele fez

1. **Ubatuba:** a base traz, por escola, o salário total e o base por 40
   horas do magistério. Mediana das escolas: R$ 10,9 mil (total) e R$ 7,7
   mil (base); a carga horária mais comum é 31 horas. A data da carga está
   em `/fontes` (24/11/2026). Ele tem o número para a planilha de custos.
2. **Taubaté:** a base sai com as 127 escolas municipais sem nenhum
   salário: lá o SIOPE só traz o total da Secretaria, sem separar as
   escolas. O painel de uma escola mostra o custo do ano da Secretaria, as
   categorias e o número de profissionais, mas nenhum salário médio. O
   SIOPE, porém, traz o salário e a carga de cada pessoa também no total da
   Secretaria.
3. **A conta que ele tentaria:** conferido no banco, em Taubaté (março de
   2026), 2.560 profissionais do magistério têm carga 18, com salário total
   médio de R$ 7.172. Convertido "para 40 horas", daria R$ 15,9 mil, o que
   não existe numa rede municipal. A carga 18 parece ser em aulas ou uma
   jornada parcial, e não em horas semanais. Em Ubatuba, a carga típica é
   31, e a conversão fica plausível.
4. **Para a decisão:** ele usa Ubatuba como referência e deixa Taubaté sem
   número. Para escolher entre as duas cidades, a comparação de salário
   fica pela metade.

## O que funciona para ele

- O salário total e o base por 40 horas, por escola, nos municípios com
  folha por escola, com a data da carga.
- A triagem de cidades e o convênio, da rodada anterior.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QI-01 | atrapalha | **O município só com o total da Secretaria fica sem salário nenhum.** O salário do magistério sai só por escola, na base. Onde o SIOPE não separa as escolas (Taubaté), nem a base nem o painel dão um salário médio, embora o SIOPE traga o salário e a carga de cada pessoa no total da Secretaria. Pedido: o salário do magistério da rede inteira por município e ano (mediana do total e do base, e a carga mais comum), também com a folha da Secretaria, no painel da Secretaria e na tela da base. | Taubaté 2026: base com 127 escolas e nenhum salário; painel da Secretaria com custo e categorias, sem salário médio | P3, P2, P6 |
| QI-02 | incomoda | **A conversão "para 40 horas" supõe que a carga está em horas.** Onde a carga parece estar em aulas ou numa jornada parcial, o salário por 40 horas sai inflado. Pedido: ao lado do salário por 40 horas, a carga mais comum do município e o salário sem conversão, e um aviso quando a carga típica não parece ser em horas semanais (ex.: menos de 20). | Taubaté, março de 2026: 2.560 professores com carga 18 e salário total médio de R$ 7.172 (R$ 15,9 mil "por 40 h"); Ubatuba, carga típica 31 | P3, P4, P6 |

Continua aberto: #429 (o bairro, com os setores do Censo 2022).

## Veredito

**Adotaria, em piloto, para escolher a cidade** (mantido). O salário da
prefeitura entra na planilha de custos em Ubatuba. Em Taubaté, falta o
número (QI-01), e a conta por 40 horas, se feita, sairia errada (QI-02).

## Encaminhamento

Issues **#571** (QI-01) e **#572** (QI-02), abertas com a aprovação do developer.
