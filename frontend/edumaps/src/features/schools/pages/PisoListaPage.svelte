<script>
  // #601 (QC-01 da P2): quem fica abaixo do piso no ano na rede municipal,
  // uma linha por pessoa, com a regra da contagem do painel e o CSV.
  import { onMount } from "svelte";
  import { DataTable, ordenar } from "@/shared/ui";
  import FonteDado from "@/features/fontes/components/FonteDado.svelte";
  import { ApiError } from "@/shared/api/client.js";
  import { getPisoLista, urlPisoCsv } from "../api/pisoApi.js";
  import { textoQuebraAno, textoPisoCusto } from "@/features/fontes/utils.js";

  const POR_PAGINA = 100;
  let dados = $state(null);
  let loading = $state(true);
  let erro = $state(null);
  let semLista = $state(null);
  let ibge = $state("");
  let filtro = $state("");
  let situacao = $state("");
  let pagina = $state(0);
  let ordem = $state({ campo: null, dir: null });

  const brl = (v) => (v == null ? "—" : Number(v).toLocaleString("pt-BR", { style: "currency", currency: "BRL" }));
  const ROTULO_SIT = { efetivo: "efetivo", temporario: "temporário", outros: "outra" };

  const pessoas = $derived(dados?.pessoas ?? []);
  // #605: o custo no formato da contagem do painel, para o mesmo texto
  const custo = $derived(dados ? { abaixo_piso: dados.total, abaixo_piso_diferenca_mensal: dados.diferenca_mensal,
    abaixo_piso_diferenca_situacao: dados.diferenca_situacao } : null);
  const porSituacao = $derived(pessoas.reduce((a, p) => ({ ...a, [p.situacao]: (a[p.situacao] ?? 0) + 1 }), {}));
  const filtrados = $derived(pessoas.filter((p) =>
    (!filtro.trim() || (p.nome ?? "").toLowerCase().includes(filtro.trim().toLowerCase()))
    && (!situacao || p.situacao === situacao)));
  // #602: ordena a lista filtrada inteira, depois corta a página
  const ordenados = $derived(ordenar(filtrados.map((p) => ({ ...p, onde: onde(p), n_escolas: p.inep_escolas.length })), ordem.campo, ordem.dir));
  const paginas = $derived(Math.max(1, Math.ceil(ordenados.length / POR_PAGINA)));
  const visiveis = $derived(ordenados.slice(pagina * POR_PAGINA, (pagina + 1) * POR_PAGINA));

  function onde(p) {
    const partes = [];
    if (p.secretaria) partes.push("Secretaria");
    const n = p.inep_escolas.length;
    if (n === 1) partes.push(p.escolas[0] ?? `escola ${p.inep_escolas[0]}`);
    else if (n > 1) partes.push(n <= 3 && p.escolas.length === n ? p.escolas.join(", ") : `${n} escolas`);
    return partes.join(" e ") || "—";
  }

  const columns = [
    { key: "nome", label: "Profissional" },
    { key: "cpf_mascarado", label: "CPF (SIOPE)" },
    { key: "situacao", label: "Situação no ano", render: (p) => ROTULO_SIT[p.situacao] ?? p.situacao },
    { key: "carga_comum", label: "Carga", render: (p) => (p.carga_comum == null ? "—" : `${p.carga_comum}h`) },
    // #607 (QD-04 da P2): a base do mês típico, da mesma mediana da base por 40 h
    { key: "base_mensal_tipica", label: "Base mensal (mês típico)", render: (p) => brl(p.base_mensal_tipica) },
    { key: "base_40h", label: "Base por 40 h", render: (p) => brl(p.base_40h) },
    // #605 (QD-01 da P2): o piso proporcional à carga e quanto falta por mês
    { key: "piso_proporcional", label: "Piso na carga", render: (p) => brl(p.piso_proporcional) },
    { key: "diferenca_mensal", label: "Falta por mês", render: (p) => brl(p.diferenca_mensal) },
    { key: "meses", label: "Meses" },
    { key: "onde", label: "Onde recebeu" },
  ];

  onMount(() => {
    const q = new URLSearchParams(window.location.search);
    ibge = q.get("ibge") ?? "";
    const ano = q.get("ano") ?? undefined;
    if (!/^\d{7}$/.test(ibge)) {
      erro = "Município inválido.";
      loading = false;
      return;
    }
    getPisoLista(ibge, ano)
      .then((d) => { dados = d; })
      .catch((e) => {
        if (e instanceof ApiError && e.status === 404) semLista = e.message || "Sem a lista para este município e ano.";
        else erro = "Erro ao carregar a lista.";
      })
      .finally(() => { loading = false; });
  });
</script>

<div class="max-w-6xl mx-auto px-4 py-6 space-y-4">
  {#if loading}
    <h1 class="text-2xl font-bold">Carregando a lista…</h1>
  {:else if erro}
    <div class="bg-red-50 border border-red-200 text-red-800 p-4 rounded-md"><p class="font-medium">Erro</p><p class="text-sm">{erro}</p></div>
  {:else if semLista}
    <h1 class="text-2xl font-bold">Abaixo do piso no ano</h1>
    <p class="text-gray-700" data-testid="sem-lista-piso">{semLista}</p>
  {:else if dados}
    <h1 class="text-2xl font-bold">Abaixo do piso em {dados.ano}: {dados.municipio ?? `município ${dados.codigo_ibge}`}{dados.uf ? ` (${dados.uf})` : ""}</h1>
    <p class="text-gray-800" data-testid="resumo-lista-piso">
      {dados.total.toLocaleString("pt-BR")} {dados.total === 1 ? "profissional do magistério fica" : "profissionais do magistério ficam"} abaixo do piso de {dados.ano}
      ({brl(dados.piso)} por 40 horas) no mês típico, em toda a folha da rede municipal (escolas e Secretaria), entre quem recebeu 3 meses ou mais:
      {["temporario", "efetivo", "outros"].filter((s) => porSituacao[s]).map((s) => `${porSituacao[s].toLocaleString("pt-BR")} ${s === "outros" ? "de outra situação" : ROTULO_SIT[s] + (porSituacao[s] === 1 ? "" : "s")}`).join(", ")}.
      É a mesma regra da contagem do painel; a situação é a dos mais meses no ano.
    </p>
    {#if textoPisoCusto(custo, dados.ano)}
      <!-- #605 (QD-01 da P2): quanto custa pôr todos no piso -->
      <p class="text-gray-800" data-testid="custo-lista-piso">
        {textoPisoCusto(custo, dados.ano)}A diferença de cada pessoa é o piso proporcional à carga menos a base do mês típico; não é o custo legal da adequação.
      </p>
    {/if}
    {#if textoQuebraAno(dados.comparacao_ano_anterior, dados.ano)}
      <!-- #604 (QD-02 da P2): a folha do ano não se compara à do anterior -->
      <p class="text-sm text-amber-900 bg-amber-50 border border-amber-200 rounded-md px-4 py-3" role="note" data-testid="quebra-ano-lista">
        {textoQuebraAno(dados.comparacao_ano_anterior, dados.ano)}
      </p>
    {/if}
    <p class="text-sm text-amber-900 bg-amber-50 border border-amber-200 rounded-md px-4 py-3" role="note">
      Não é a verificação legal do piso: complementos, jornada, licenças e reajuste pago com atraso mudam a leitura. O total da Secretaria
      pode ter pagamentos parciais. O CPF é o que o SIOPE publica, mascarado.
    </p>
    <div class="flex flex-wrap items-center gap-3 text-sm" data-testid="filtros-lista-piso">
      <a class="px-3 py-1 border rounded-md bg-blue-50 text-blue-800" href={urlPisoCsv(ibge, dados.ano)} download data-testid="csv-lista-piso">Baixar CSV</a>
      <label class="text-gray-600" for="piso-nome">Buscar pelo nome</label>
      <input id="piso-nome" type="search" bind:value={filtro} oninput={() => (pagina = 0)} class="border border-gray-300 rounded-md px-2 py-1 text-sm" />
      <label class="text-gray-600" for="piso-situacao">Situação</label>
      <select id="piso-situacao" bind:value={situacao} onchange={() => (pagina = 0)} data-testid="piso-situacao" class="border border-gray-300 rounded-md px-2 py-1 text-sm">
        <option value="">todas</option><option value="efetivo">efetivo</option><option value="temporario">temporário</option><option value="outros">outras</option>
      </select>
      <span class="text-gray-600" data-testid="contagem-lista-piso">{filtrados.length.toLocaleString("pt-BR")} {filtrados.length === 1 ? "pessoa" : "pessoas"} · página {pagina + 1} de {paginas}</span>
      <button type="button" class="px-2 py-1 border rounded-md disabled:opacity-50" disabled={pagina === 0} onclick={() => (pagina -= 1)}>← Anterior</button>
      <button type="button" class="px-2 py-1 border rounded-md disabled:opacity-50" disabled={pagina >= paginas - 1} onclick={() => (pagina += 1)}>Próxima →</button>
    </div>
    <DataTable {columns} data={visiveis} caption="Profissionais do magistério abaixo do piso no ano"
      onsort={(campo, dir) => { ordem = { campo, dir }; pagina = 0; }} />
  {/if}
  <FonteDado tela="folha" class="pt-2" />
</div>
