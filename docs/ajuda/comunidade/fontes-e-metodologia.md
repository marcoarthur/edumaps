---
titulo: "Fontes e metodologia"
publico: [comunidade]
modulo: comunidade
nivel: basico
status: ativo
relacionadas: [comparar-redes, painel-publico-da-escola, privacidade]
funcionalidade: ../../funcionalidades/plataforma/fontes-de-dados.md
ultima_revisao: 2026-11-16
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
3. **Para conferir o arquivo:** abra **Arquivos da última carga**. Cada
   arquivo traz o endereço oficial e o SHA-256, que permite verificar que é o
   mesmo arquivo publicado pelo órgão.
4. **Para citar uma análise:** use o ano do selo **Fonte** da própria tela. No
   agrupamento de escolas, a caixa **Universo** diz o ano do Censo e do IDEB
   usados, e o CSV baixado é aquele resultado.
5. **Para citar um índice do EduMaps** (infraestrutura, docentes,
   diversidade e os outros do ranking de escolas): o cartão **Índices do
   EduMaps** diz a **versão da fórmula** (ex.: `indices-v3`) e abre o
   histórico das versões. A versão também vai no CSV do ranking de escolas
   (coluna `versao_indice`).

## Entendendo os números
- **"Carga não registrada"**: a base foi carregada antes de o registro de
  cargas existir. O ano do dado continua certo (vem da própria base); só a
  data da carga não é conhecida.
- **"Consulte os termos do órgão"**: a licença ainda não foi confirmada por
  nós; vale o que o órgão publica.
- **Ausência não é zero**: "–" ou "n/d" quer dizer que a fonte não tem o dado.
- **Índices do EduMaps** não são de um órgão: são calculados por nós a
  partir do Censo Escolar. No lugar da licença e da carga, o cartão traz a
  versão da fórmula e a data do **último cálculo**. Notas de versões
  diferentes não são comparáveis; o histórico diz o que mudou em cada uma.

## Limitações conhecidas
- A página lista as bases das análises públicas. As do painel do gestor
  (saúde, trânsito, cobertura do solo, contas municipais) entram depois.
- A folha de pagamento cobre só os municípios já carregados.

## Veja também
- [Comparar redes](comparar-redes.md)
- [Privacidade e dados públicos](privacidade.md)
