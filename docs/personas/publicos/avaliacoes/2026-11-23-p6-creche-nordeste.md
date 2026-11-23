# Reavaliação: P6 apura onde falta creche no Nordeste (2026-11-23)

Quinta rodada da P6 (terceiro setor e jornalismo de dados), a pedido do
developer. A última foi em 2026-11-16 (pautas revisitadas), com o veredito
**adotaria**. Desde então, nas telas públicas:

| Entrega | O quê |
|---|---|
| #462, #489 | versão citável dos índices e do IVET em `/fontes` |
| #516 a #520 | creche e pré-escola separadas, conveniadas como teto |
| #531 | CEP, bairro e endereço na base de análise |
| #533 | população por idade do Censo 2022 e taxa de atendimento na comparação de redes |
| #535 | taxa de atendimento da creche e da pré-escola no ranking de redes, com a meta e o CSV |

- **Avaliou:** só a P6.
- **Material:**
  - o ranking de redes com o indicador da creche, no Nordeste, com e sem
    o porte;
  - o CSV do ranking e a base de análise de três municípios do topo da
    lista, para conferir;
  - `/fontes` e o rodapé de fontes da página.
- **O trabalho que ela faria:** a jornalista de dados de um veículo do
  Nordeste prepara a pauta "Onde falta creche no Nordeste", com a meta do
  PNE, os municípios mais longe dela e as capitais. A pergunta do perfil
  dela é "posso citar este número, e com qual fonte?".
- ⚠️ Simulação: não substitui uma jornalista de verdade.

## O que ela fez

1. **O número da pauta:** no ranking de redes, indicador "Creche (0 a 3
   anos)", região Nordeste: **1.305 dos 1.794 municípios** estão abaixo
   dos 50% da meta. A nota diz a conta, os anos (Censo Demográfico 2022 e
   Censo Escolar 2025) e que a taxa pode passar de 100% (12 municípios
   passam).
2. **Os mais longe da meta:**
   - no topo, dois municípios sem matrícula em creche: Feira Nova (SE) e
     Jaborandi (BA);
   - Moreno (PE), com 2.673 crianças de 0 a 3 anos, tem 6,9%, e todas as
     matrículas são da rede privada.

   **Ela confere antes de publicar:** na base de análise (blocos Etapas,
   Matrículas e Parceria), nenhuma das escolas de Feira Nova e de
   Jaborandi oferece creche, e em Moreno nenhuma escola municipal oferece.
   O ranking bate com a base, escola por escola.
3. **As capitais:** com o porte "mais de 500 mil", as 11 cidades grandes
   do Nordeste estão abaixo da meta, de Jaboatão dos Guararapes (17,5%)
   a Recife (39,9%). A coluna do teto mostra uma segunda pauta: em São Luís
   a rede municipal atende 7,1% e, com as conveniadas, chega a 26,4%; em
   Salvador, 8,8% e 25,5%.
4. **O link e o arquivo:** o endereço da página guarda o indicador, a
   região e o porte. O CSV `ranking-atendimento-creche-NE-…-2022.csv` traz
   as três taxas, as crianças, as matrículas, a meta e o recorte em cada
   linha.
5. **A fonte, para o rodapé da matéria:** o rodapé "Fonte:" da página
   lista o Censo Escolar 2025, o IDEB e o SAEB, o INSE, a estimativa da
   população de 2025 e os Índices do EduMaps. **Não lista o Censo
   Demográfico 2022**, de onde vêm as crianças, que é o denominador da
   taxa. E lista bases que não entram nessa conta (IDEB, INSE, Índices). A
   fonte certa só aparece em `/fontes` ou na comparação de redes de cada
   município. O texto do topo da página também segue o do IDEB ("o nível
   socioeconômico (INSE) aparece ao lado"), e a tabela da creche não tem
   INSE.
6. **"Quem mais abriu vagas?":** a pergunta típica dela ("quais redes mais
   melhoraram") não tem resposta para a creche. Só há matrículas do Censo
   Escolar 2025 carregadas. A série depende da carga de outros anos do
   Censo Escolar.

## O que funciona para ela

- Um número de manchete que se confere: o ranking bate com a base, escola
  por escola.
- O link estável com o recorte e o CSV com o recorte em cada linha.
- As três contas lado a lado, que dão a segunda pauta (o peso das
  conveniadas nas capitais).
- Os avisos da nota (anos diferentes, mais de 100%, município pequeno).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QN-01 | atrapalha | **O rodapé de fontes do ranking não cita o Censo Demográfico na taxa de atendimento.** Com o indicador da creche ou da pré-escola, o rodapé "Fonte:" lista as bases do IDEB (IDEB e SAEB, INSE, Índices do EduMaps), que não entram na conta, e não lista a população por idade do Censo 2022, que é o denominador. O texto do topo também fala do INSE, que essa tabela não tem. Pedido: rodapé de fontes pelo indicador (na taxa: Censo Escolar e população por idade do Censo Demográfico); o texto do topo sem o INSE nesses indicadores. | `/ranking?aba=redes&indicador=atendimento_creche&regiao=NE&porte=mais_500mil`; o cartão `ibge_populacao_idade` só vale para `comparacao_redes` e `base_analise` em `/fontes` | P6, P5, P4 |

Continua aberto: #454 (VJ-05, registro da carga do IDEB em `/fontes`; o
rodapé ainda diz "carga não registrada").

Observação, sem pedido: a variação da taxa de atendimento ("quem mais
abriu vagas") depende de carregar mais anos do Censo Escolar.

## Veredito

**Adotaria** (mantido). A pauta da creche sai inteira da plataforma, com
o número conferido. Só a citação da fonte exige uma volta a `/fontes`
(QN-01).

## Encaminhamento

Issue **#539** (QN-01), aberta com a aprovação do developer.

## Andamento

- 2026-11-23: #539 (PR #540) mergeado: QN-01 resolvido.
  - Com a taxa de atendimento, o rodapé do ranking cita o Censo Escolar, a
    estimativa da população e a população por idade do Censo Demográfico,
    sem as bases do IDEB. O texto do topo não fala do INSE.
  - #454 (registro da carga do IDEB) segue aberta.
