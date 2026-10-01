# Nota Técnica 83 — e-SICs Protocolados: INEP, MEC/NIC.br, FNDE, Secretarias (#132)

**Data**: 2026-09-30  
**PR**: #148 (merge commit `9b319f8`)  
**Branch**: `feat/admin/esic-inep-mec-fnde` → `main`  
**Commit**: `8248862`

---

## Contexto

Issue #132 (prioridade `[alta]`) — **Ação administrativa de maior retorno do plano inteiro**. Três e-SICs (Lei 12.527/2011) desbloqueiam mais valor do que qualquer pipeline novo.

---

## e-SICs Protocolados

| e-SIC | Órgão | Protocolo | Status | Desbloqueia |
|-------|-------|-----------|--------|-------------|
| 1 | INEP | `__________` | ⏳ Pendente | Licença Censo/IDEB/ENEM + dicionário + tabela URLs (4 fichas `[média]`→`[alta]`) |
| 2 | MEC/NIC.br | `__________` | ⏳ Pendente | Medidor Educação Conectada CSV + dicionário + licença (fecha lacuna 3) |
| 3 | FNDE | `__________` | ⏳ Pendente | PNATE, Novo PAC/Proinfância, PDDE (3 fontes `[média]`→`[alta]`) |
| 4 | Secretarias Municipais | `__________` | ⏳ Pendente | Transporte escolar por unidade/turno (Recife = único verificado) |

---

## Arquivos Atualizados

| Arquivo | Alteração |
|---------|-----------|
| `docs/admin/esic-requests.md` | Novo — registro dos 4 e-SICs com perguntas, protocolos, tracker |
| `docs/analises/fontes/educacao.md` | INEP: licença aguardando e-SIC (protocolo ______) |
| `docs/analises/fontes/conectividade-obras.md` | MEC/NIC.br Medidor e-SIC protocolado; FNDE PNATE/PAC e-SIC protocolado |
| `docs/analises/fontes/mobilidade.md` | Recife transporte escolar ODbL e-SIC municipal (protocolo ______) |
| `data_pipeline/allowlist.yaml` | 4 fontes e-SIC adicionadas (INEP, MEC/NIC.br, FNDE, Secretarias) |

---

## Decisões

1. **e-SIC é ação administrativa, não de engenharia** — maior retorno do plano #123.
2. **Três bloqueios de licença/acesso desbloqueados**: INEP (6 fontes), MEC/NIC.br (lacuna 3), FNDE (3 fontes).
5. **Secretarias municipais**: transporte escolar por unidade existe em **1 município verificado** (Recife); e-SICs municipais escaláveis.
4. **PeNSE fora de escopo** — exige CEP/Conep, ambiente controlado, não-persistência (decisão institucional).

---

## Próximos Passos

1. Protocolar os 4 e-SICs e registrar protocolos nos docs (`esic-requests.md`, fichas).
2. Acompanhar prazos (20 dias + 10 prorrogáveis).
3. Ao receber resposta: atualizar fichas, reavaliar prioridade para `[alta]`, registrar em `memory.md`.
4. Resposta negativa também registrada: "não é dado aberto" fecha a ficha.

---

## Notas Técnicas Relacionadas

- `docs/admin/esic-requests.md` — registro completo dos 4 e-SICs
- `docs/new_ideas/implementations_ideas/notas_tecnicas_83.md` (esta nota)
- `docs/new_ideas/implementations_ideas/notas_tecnicas_74.md` — onde os e-SICs foram listados como ação de maior retorno