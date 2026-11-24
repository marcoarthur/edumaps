---
titulo: "Fontes e metodologia"
publico: [comunidade]
modulo: comunidade
nivel: basico
status: ativo
relacionadas: [comparar-redes, painel-publico-da-escola, privacidade]
funcionalidade: ../../funcionalidades/plataforma/fontes-de-dados.md
ultima_revisao: 2026-11-24
---

# Fontes e metodologia

> **Para quem:** quem precisa citar ou conferir um número do EduMaps
> **Tempo de leitura:** ~2 min

## Em 30 segundos
Toda análise pública traz, no pé, um selo **Fonte** com a base, o ano do dado
e a data da carga. O link **Fontes e metodologia** (também no rodapé de todas
as páginas) abre a lista completa das bases, com o link oficial de cada órgão.

## Passo a passo
1. **Onde ir:** rodapé de qualquer página → **Fontes e metodologia** (ou o
   endereço `/fontes`). Não precisa de login.
2. **Leia o cartão da base:** órgão, **ano do dado**, **última carga**,
   licença e as telas que usam a base.
3. **Para conferir o arquivo:** quando a carga registra os arquivos baixados,
   o cartão traz **Arquivos da última carga**, cada um com o endereço oficial
   e o SHA-256, que permite verificar que é o mesmo arquivo publicado pelo
   órgão. A maior parte das bases foi carregada antes desse registro, e os
   arquivos delas aparecem a partir da próxima carga. A população por idade
   do Censo Demográfico já traz o arquivo.
4. **Para citar uma análise:** use o ano do selo **Fonte** da própria tela.
   O selo lista as bases da conta que a tela mostra: no ranking, com o
   indicador da creche ou da pré-escola, ele traz o Censo Escolar, a
   população por idade do Censo Demográfico e a estimativa da população, e
   não o IDEB. O CSV dos rankings leva as mesmas bases em toda linha, nas
   colunas `fontes` e `fontes_links`. No
   agrupamento de escolas, a caixa **Universo** diz o ano do Censo e do IDEB
   usados, e o CSV baixado é aquele resultado.
5. **Para citar um índice do EduMaps** (infraestrutura, docentes,
   diversidade e os outros do ranking de escolas): o cartão **Índices do
   EduMaps** diz a **versão da fórmula** (ex.: `indices-v7`) e abre o
   histórico das versões. A versão também vai no CSV do ranking de escolas
   (coluna `versao_indice`).
6. **Para citar o IVET** (vulnerabilidade de acesso, no painel da escola): o
   cartão **IVET do EduMaps** diz a versão da fórmula (ex.: `ivet-v1.8`) e o
   histórico. A mesma versão aparece no painel, ao lado da data da medição.

## Entendendo os números
- **"Carga não registrada"**: a base foi carregada antes de o registro de
  cargas existir. O ano do dado continua certo (vem da própria base); só a
  data da carga não é conhecida.
- **Sem "Arquivos da última carga"**: a carga não registrou os arquivos
  baixados (o caso de todas as bases desta página até a próxima carga). O
  ano do dado e a data da carga continuam valendo; só não dá para conferir o
  SHA-256 por aqui.
- **"Consulte os termos do órgão"**: a licença ainda não foi confirmada por
  nós; vale o que o órgão publica.
- **Ausência não é zero**: "–" ou "n/d" quer dizer que a fonte não tem o dado.
- **Índices do EduMaps** não são de um órgão: são calculados por nós a
  partir do Censo Escolar. No lugar da licença e da carga, o cartão traz a
  versão da fórmula e a data do **último cálculo**. Notas de versões
  diferentes não são comparáveis; o histórico diz o que mudou em cada uma.
  O mesmo vale para o **IVET do EduMaps**: no lugar da carga, a data do
  último cálculo do painel.

## Limitações conhecidas
- A página lista as bases das análises públicas. As do painel do gestor
  (saúde, trânsito, cobertura do solo, contas municipais) entram depois.
- A folha de pagamento cobre só os municípios já carregados. O cartão do
  SIOPE lista esses municípios, com os anos, os meses e as escolas de cada
  um; município em que o SIOPE só traz o total da Secretaria aparece como
  tal. Um mês com a folha pela metade aparece marcado, por exemplo "2025
  (12 meses (setembro e outubro incompletos), 167 escolas)": nele há menos
  categorias de profissionais que o habitual do ano, ou menos da metade dos
  registros de um mês típico. Com a carga registrada, a lista diz "já na
  planilha do SIOPE": os dados são os da planilha baixada naquela data, e a
  falta está na fonte. Sem registro, a causa pode ser a declaração do
  município ao SIOPE ou a carga. Quando o município passa a declarar a
  folha no total da Secretaria, sem separar as escolas, a lista diz em que
  meses ela é por escola, por exemplo "2026 (por escola só em janeiro e
  fevereiro; de março a agosto, só o total da Secretaria; 168 escolas)". O
  mês conta como da Secretaria quando a maior parte do valor declarado está
  nela.
- Cada carga da folha é registrada: o município, o ano, a data e a planilha
  baixada do SIOPE (com o SHA-256). A lista diz a data da carga de cada
  município e ano ("carga em 24/11/2026"), e o cartão, a mais recente. As
  cargas feitas antes desse registro aparecem como "carga não registrada":
  nenhuma data é inventada.

## Veja também
- [Comparar redes](comparar-redes.md)
- [Privacidade e dados públicos](privacidade.md)
