# Nota técnica — Financeiro: escopo de rede no agregado da Secretaria

> Data: 2026-09-22 · Ciclo: frontend (Svelte 5) + docs

## 1. Contexto

O PR #91 passou a exibir o agregado da Secretaria quando o SIOPE não detalha a
folha por escola (ex.: Taubaté). O usuário apontou um risco de produto: mostrar
esse número no painel **de uma escola** é **misleading** — não dá para saber quem
trabalha ali. O número é da rede inteira.

## 2. Decisão

**Manter o dado, mas nunca apresentá-lo como da escola.** Quando a origem é o
agregado da Secretaria (`origem='secretaria'`), todo o painel é **escopado como
rede municipal**, deixando explícito o que o número representa e o que ele **não**
permite afirmar.

## 3. Mudanças

`SchoolFinance.svelte` (quando `origem === 'secretaria'`):
- Aviso destacado no topo: **"Painel da rede municipal — não desta escola"**,
  explicando que o SIOPE não detalha por escola e que os números são da rede.
- Escopo nos títulos/cards:
  - `Custo total (período) · Rede municipal (Secretaria)`
  - `Profissionais (total) · Rede municipal (Secretaria)`
  - `Custo total mensal — rede municipal`
  - `Profissionais por mês — rede municipal`
  - `Custo por categoria — rede municipal`
  - `Categorias profissionais — rede municipal`
- **"Ver folha completa"** (que lista nomes) **desabilitado**, com explicação de
  que a folha detalhada não existe nesse caso.

`origem='escola'` permanece **sem** escopo de rede (comportamento anterior).

## 4. Validação

- Frontend (container): `SchoolFinance.test.js` + `SchoolFinancePage.test.js` →
  **10 ok** (novo caso: aviso de rede, título escopado e botão desabilitado);
  suite completa **304 ok** (4 falhas pré-existentes).
- Deploy: `deploy_frontend_dev` → **PR #92** (merge `bf54363`).
- Docs: capacidade `analise/financeiro` atualizada ("escopado como rede
  municipal; folha detalhada indisponível").

## 5. Lição de produto

**Agregado ≠ unidade.** Quando o dado de origem não permite atribuir a uma
escola, o correto é **mudar o escopo da apresentação**, não só adicionar um
aviso: títulos, cards e ações (a folha por nomes) precisam refletir o escopo
real da informação.
