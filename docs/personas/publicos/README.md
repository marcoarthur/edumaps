# Personas de público (plano de negócios)

Personas **ativas neste repositório** que avaliam o EduMaps pelo ponto de vista
de quem usa ou paga. Saem dos seis públicos do plano de negócios
(`~/Documents/EduMaps/Business-Plan/publicos-alvo.md`, de 2026-10-10).

Diferem das outras personas do projeto:

| Persona | Onde | Papel |
|---|---|---|
| Tech Lead | [`../tech-lead.md`](../tech-lead.md) | organiza o acervo e propõe direções técnicas |
| Personas do `eduBR` (pesquisadora, especialista em ML, gestora escolar) | repositório `eduBR`, **só leitura** | curadoria do pacote de dados |
| **Personas de público (estas)** | aqui | avaliam as **funcionalidades** do produto |

⚠️ **São simulações.** A avaliação é um ensaio guiado pelo perfil do plano de
negócios, não uma pesquisa com usuários. Ela serve para achar lacunas cedo e
preparar a conversa com gente de verdade, sem substituí-la. A spec dos planos
de gestão (§6) recomenda mostrar a funcionalidade a 2 ou 3 gestores reais.

## As seis personas

| Persona | Arquivo | Público | Papel no plano de negócios |
|---|---|---|---|
| Diretora de escola municipal | [`p1-gestor-escolar.md`](p1-gestor-escolar.md) | P1 | 🔑 habilitador: a adoção dela sustenta a renovação |
| Secretário municipal de educação | [`p2-secretaria-municipal.md`](p2-secretaria-municipal.md) | P2 | 🎯 alvo principal: maior ticket e recorrência |
| Mantenedor de rede privada | [`p3-rede-privada.md`](p3-rede-privada.md) | P3 | 🥇 entrada: ciclo curto, financia o B2G |
| Pesquisadora em políticas educacionais | [`p4-academia.md`](p4-academia.md) | P4 | 🥈 imediata: validação metodológica |
| Auditor de controle externo / conselheiro | [`p5-orgaos-de-controle.md`](p5-orgaos-de-controle.md) | P5 | ⏳ estratégico, depende de decisão de posicionamento |
| Analista de ONG ou jornalista de dados | [`p6-terceiro-setor.md`](p6-terceiro-setor.md) | P6 | 🥉 visibilidade |

## Protocolo de avaliação de uma funcionalidade

1. **Aplicabilidade.** Para cada persona, decidir se a funcionalidade se
   aplica a ela, pelo campo `audiencia` da ficha em `docs/funcionalidades/` e
   pelo "o que usa" do perfil. As que não se aplicam registram
   **"não se aplica"** com o motivo, na matriz abaixo.
2. **Material.** A persona lê a ficha da funcionalidade, a página de ajuda e a
   spec, e percorre as telas com os **dados de demonstração** (os mocks dos
   testes, sem login real). Não avalia código.
3. **Avaliação.** No arquivo da persona, uma entrada datada com:
   - o que ela tentou fazer (as perguntas típicas do perfil);
   - o que funciona para ela;
   - as barreiras, cada uma com a gravidade (**bloqueia**, **atrapalha**,
     **detalhe**) e a evidência (tela, texto da ajuda);
   - o veredito: **adotaria**, **adotaria com ressalvas** ou **não
     adotaria**, e por quê.
4. **Consolidação.** Um arquivo em [`avaliacoes/`](avaliacoes/) junta as
   avaliações da funcionalidade, separa defeito de lacuna e propõe o
   encaminhamento. **Issues só são abertas com a aprovação do developer.**
5. **Memória.** Cada persona mantém "Pendências" (o que voltar a checar
   quando algo mudar). Uma avaliação nova começa lendo as pendências.
6. **Fechamento do ciclo.** Ao fim de cada ciclo de desenvolvimento, junto da
   nota técnica, um arquivo em [`ciclos/`](ciclos/README.md) registra, para
   **cada** público (P1 a P6), o que mudou, o impacto para o usuário e a
   evolução do veredito. Público sem mudança também aparece, com o motivo.
   Cada persona ganha a linha do ciclo em "Progresso por ciclo".

## Matriz de aplicabilidade

| Funcionalidade | P1 | P2 | P3 | P4 | P5 | P6 | Avaliação |
|---|---|---|---|---|---|---|---|
| Planos de gestão acompanháveis (épico #368) | ✅ | ✅ parcial | — | — | — | — | [2026-11-12](avaliacoes/2026-11-12-planos-de-gestao.md), [reavaliação](avaliacoes/2026-11-12-planos-de-gestao-reavaliacao.md) |
| Visão da rede (#375) | ✅ parcial | ✅ | — | — | — | — | [2026-11-13](avaliacoes/2026-11-13-visao-da-rede.md) |

Motivos de "não se aplica" para os planos de gestão:

- **P3 (rede privada):** o plano acompanhável segue o formato da escola pública
  (PDDE, PDE Escola, PPP) e não é o que o perfil usa (captação, benchmark de
  mercado). Reavaliar se a rede privada pedir o acompanhamento de metas por
  unidade.
- **P4 (academia):** o plano é dado interno da escola, sem agregação nem
  exportação para pesquisa, e não é público.
- **P5 (órgãos de controle):** recebe o relatório **do município**, não usa a
  ferramenta. Avaliar como produto para o fiscal depende da decisão de
  posicionamento que o plano de negócios pede (P5, "Ressalva honesta").
- **P6 (terceiro setor):** o plano não é público, e o perfil usa dado aberto
  e citável.
