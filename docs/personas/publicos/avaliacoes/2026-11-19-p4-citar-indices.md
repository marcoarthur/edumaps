# Reavaliação: P4 e a citação dos índices do EduMaps (2026-11-19)

Vigésima quarta rodada da P4 (academia), a pedido do developer, depois da
entrega da vigésima terceira rodada:

| Entrega | O quê |
|---|---|
| #500 | variação do ranking de redes nas mesmas escolas (RF-01) |

- **Avaliou:** só a P4.
- **Material:**
  - a página `/fontes` e a resposta `/api/fontes`;
  - a ajuda `fontes-e-metodologia.md` e a ajuda `rankings.md` ("O que cada
    índice mede");
  - o documento de método aberto por "Fórmula completa" no cartão dos
    índices (`docs/analises/ivet.md`, seção 2.2);
  - o registro de cargas (`clean.import_metadata`), só leitura.
- **O trabalho que ela faria:** citar num artigo os índices do EduMaps que
  ela baixou pela base de análise (capacitação docente e infraestrutura),
  com a versão da fórmula e a fonte, e conferir o arquivo do Censo usado.
  A ajuda diz: "Para citar, informe a versão".
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A versão em cada lugar.** Ela abriu os quatro lugares que falam da
   versão da fórmula dos índices:

   | Onde | Versão que diz ser a atual |
   |---|---|
   | `/fontes`, cartão "Índices do EduMaps", e o CSV (`versao_indice`) | `indices-v6` |
   | ajuda `fontes-e-metodologia.md` e `base-de-analise.md` (exemplo) | `indices-v6` |
   | ajuda `rankings.md`, "Versão da fórmula" | "A atual é a **`indices-v5`**", e o exemplo de arquivo `…-indices-v5.csv` |
   | "Fórmula completa" (link do cartão), seção 2.2 | "Versão citável dos seis scores: `indices-v2` (2026-11-16)" |

   - Na ajuda de rankings, a `indices-v6` aparece mais abaixo, no texto da
     capacidade gestora ("Antes da `indices-v6`…"), mas a frase "a atual
     é" ficou na v5.
   - Na fórmula completa, a tabela já descreve as mudanças da v3 à v6, mas
     o cabeçalho da seção ainda diz v2. Na diversidade, a inclusão é datada
     pela versão do IVET (`ivet-v1.4`) em vez da `indices-v2`, que é a
     versão dos índices em que ela mudou (o histórico de `/fontes` diz
     isso).
   - O teste `indices_versao.t` confere o código e o comentário da tabela no
     banco; os textos ficam de fora, e cada mudança de fórmula (#471, #473,
     #475) atualizou uns e não outros.
2. **O arquivo da carga.** A ajuda de fontes, no passo 3, diz: "abra
   **Arquivos da última carga**. Cada arquivo traz o endereço oficial e o
   SHA-256". Nenhuma das seis bases públicas tem arquivos no registro:
   - Censo, INSE, malha, população: carga de 14/10/2026, sem manifesto;
   - IDEB e SIOPE: "carga não registrada".
   - Os únicos manifestos com SHA-256 do registro são de bases que não
     aparecem em `/fontes` (rendimento e distorção do INEP, ANTT).
   - A ajuda explica a "carga não registrada", mas o passo 3 promete algo
     que nenhum cartão mostra.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido) | a versão citável diverge entre a página de fontes (v6), a ajuda de rankings (v5) e a fórmula completa (v2) (RE-01); o passo "conferir o arquivo" não existe para nenhuma base pública (RE-02) |

## O que funciona

- **A versão no CSV** (`versao_indice`) e no nome do arquivo.
- **O histórico das versões** em `/fontes`, com o que mudou em cada uma.
- **A ausência honesta** de licença não verificada ("consulte os termos do
  órgão").

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RE-01 | atrapalha | **A versão citável dos índices diverge entre os textos.** `/fontes` e o CSV dizem `indices-v6`; a ajuda de rankings diz que "a atual é a `indices-v5`"; a "Fórmula completa", aberta pelo próprio cartão, diz `indices-v2`. Quem cita pela ajuda ou pela fórmula cita a versão errada. Pedido: os textos com a versão atual; a inclusão da diversidade datada pela `indices-v2`; e o teste da versão conferindo também a ajuda de rankings e a fórmula completa, para a próxima mudança não esquecer. | `rankings.md` linha "A atual é a `indices-v5`"; `ivet.md` §2.2 "Versão citável dos seis scores: `indices-v2`"; `/api/fontes` `versao = indices-v6` | P4, P6, P5 |
| RE-02 | detalhe | **"Arquivos da última carga" não existe para nenhuma base pública.** A ajuda de fontes manda conferir o SHA-256 do arquivo, mas Censo, INSE, malha e população têm carga sem manifesto, e IDEB e SIOPE não têm carga registrada. Pedido: a ajuda dizer que o arquivo só aparece nas bases cuja carga registra o manifesto (hoje nenhuma das públicas), ou registrar o manifesto na próxima carga. | `clean.import_metadata`: `raw_manifest` vazio nas tabelas das seis bases; `ideb_notas_escolas` e `remuneracao_municipal` sem linha | P4 |

## Encaminhamento

Aguardando a aprovação do developer para abrir a issue.
