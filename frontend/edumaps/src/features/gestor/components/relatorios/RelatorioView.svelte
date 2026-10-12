<!-- src/features/gestor/components/relatorios/RelatorioView.svelte -->
<script>
  // Renderiza o ReportResult do Assistente de Relatório (#219): cabeçalho
  // (título, recorte, data, selo do cache), aviso quando a redação automática
  // não esteve disponível, as seções por tipo e o rodapé com fontes e avisos.
  // Tipos de seção desconhecidos são ignorados (compatibilidade). O aviso
  // `associacao` (fase 2) sai em destaque no topo: associação não é causa.
  import SecaoTexto from "./SecaoTexto.svelte";
  import SecaoIndicadores from "./SecaoIndicadores.svelte";
  import SecaoTabela from "./SecaoTabela.svelte";
  import SecaoGrafico from "./SecaoGrafico.svelte";
  import SecaoAssociacoes from "./SecaoAssociacoes.svelte";
  import { formatarValor } from "../../utils/relatorioFormatos.js";
  import { baixarMarkdown } from "../../utils/relatorioMarkdown.js";
  import { ApiError } from "@/shared/api/client.js";

  /**
   * @type {{
   *   relatorio: object,
   *   acoes?: boolean,
   *   onSalvar?: (() => Promise<unknown>) | null,
   *   salvo?: boolean,
   * }}
   */
  let { relatorio, acoes = false, onSalvar = null, salvo = false } = $props();

  let artigo = $state(null);
  let estadoSalvar = $state("ocioso"); // ocioso | salvando | salvo | erro
  let erroSalvar = $state(null);

  const mostrarSalvar = $derived(typeof onSalvar === "function" && !salvo);
  const temAcoes = $derived(acoes || mostrarSalvar);

  // <details> abertos só para a impressão (restaurados no afterprint)
  let abertosParaImprimir = [];

  function abrirDetalhes() {
    if (!artigo || abertosParaImprimir.length) return;
    abertosParaImprimir = [...artigo.querySelectorAll("details:not([open])")];
    for (const d of abertosParaImprimir) d.open = true;
  }

  function restaurarDetalhes() {
    for (const d of abertosParaImprimir) d.open = false;
    abertosParaImprimir = [];
  }

  $effect(() => {
    window.addEventListener("beforeprint", abrirDetalhes);
    window.addEventListener("afterprint", restaurarDetalhes);
    return () => {
      window.removeEventListener("beforeprint", abrirDetalhes);
      window.removeEventListener("afterprint", restaurarDetalhes);
    };
  });

  function imprimir() {
    window.print();
  }

  function baixar() {
    baixarMarkdown(relatorio);
  }

  async function salvar() {
    if (!mostrarSalvar || estadoSalvar === "salvando" || estadoSalvar === "salvo") return;
    estadoSalvar = "salvando";
    erroSalvar = null;
    try {
      await onSalvar();
      estadoSalvar = "salvo";
    } catch (err) {
      estadoSalvar = "erro";
      erroSalvar =
        err instanceof ApiError && err.message ? err.message : "Não foi possível salvar o relatório.";
    }
  }

  const BOTAO =
    "px-3 py-1.5 rounded-md text-sm font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed";

  const secoes = $derived((relatorio?.secoes ?? []).filter((s) => s && typeof s === "object"));
  const fontes = $derived(relatorio?.fontes ?? []);
  const todosAvisos = $derived(relatorio?.avisos ?? []);
  const avisosAssociacao = $derived(todosAvisos.filter((a) => a?.tipo === "associacao"));
  const avisos = $derived(todosAvisos.filter((a) => a?.tipo !== "associacao"));
  const llmIndisponivel = $derived(relatorio?.rastreio?.llm === "indisponivel");

  const geradoEm = $derived.by(() => {
    const d = relatorio?.gerado_em ? new Date(relatorio.gerado_em) : null;
    if (!d || Number.isNaN(d.getTime())) return null;
    return d.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
  });

  const recorteTexto = $derived.by(() => {
    const r = relatorio?.recorte;
    if (!r) return "";
    return r.uf && r.nivel === "municipio" ? `${r.nome} (${r.uf})` : (r.nome ?? r.codigo ?? "");
  });
</script>

<article
  class="relatorio-imprimivel space-y-6"
  data-testid="relatorio-view"
  aria-labelledby="relatorio-titulo"
  bind:this={artigo}
>
  {#if temAcoes}
    <div class="flex flex-wrap items-center gap-2 print:hidden" role="group" aria-label="Ações do relatório" data-testid="relatorio-acoes">
      {#if acoes}
        <button type="button" onclick={imprimir} class="{BOTAO} bg-gray-200 text-gray-800 hover:bg-gray-300">
          Imprimir / salvar PDF
        </button>
        <button type="button" onclick={baixar} class="{BOTAO} bg-gray-200 text-gray-800 hover:bg-gray-300">
          Baixar Markdown
        </button>
      {/if}
      {#if mostrarSalvar}
        {#if estadoSalvar === "salvo"}
          <span class="text-sm font-medium text-emerald-700" role="status" data-testid="relatorio-salvo">
            <span aria-hidden="true">✓</span>{" "}Salvo
          </span>
          <a href="/gestor/relatorios/salvos" class="text-sm text-blue-700 hover:underline">Ver meus relatórios</a>
        {:else}
          <button
            type="button"
            onclick={salvar}
            disabled={estadoSalvar === "salvando"}
            class="{BOTAO} bg-blue-600 text-white hover:bg-blue-700"
          >{estadoSalvar === "salvando" ? "Salvando…" : "Salvar relatório"}</button>
        {/if}
      {/if}
    </div>
    {#if estadoSalvar === "erro" && erroSalvar}
      <p class="text-sm text-red-700 print:hidden" role="alert" data-testid="erro-salvar">{erroSalvar}</p>
    {/if}
  {/if}

  <header class="space-y-2">
    <div class="flex flex-wrap items-center gap-2">
      <h2 id="relatorio-titulo" class="text-xl font-bold text-gray-900">{relatorio?.titulo}</h2>
      {#if relatorio?.cache_hit}
        <span
          class="text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-200"
          data-testid="selo-cache"
        >Gerado a partir do cache</span>
      {/if}
    </div>
    <p class="text-sm text-gray-600">
      {#if relatorio?.tema?.titulo}{relatorio.tema.titulo}{" · "}{/if}{recorteTexto}{#if geradoEm}{" · "}gerado
        em {geradoEm}{/if}
    </p>
  </header>

  {#if llmIndisponivel}
    <div
      class="rounded-md bg-amber-50 border border-amber-200 text-amber-800 text-sm p-3"
      role="note"
      data-testid="aviso-llm"
    >
      A redação automática não estava disponível. O resumo abaixo é uma versão
      curta gerada sem o assistente; os dados das seções não foram afetados.
    </div>
  {/if}

  {#if avisosAssociacao.length}
    <div
      class="rounded-md bg-blue-50 border border-blue-200 text-blue-900 text-sm p-3 space-y-1"
      role="note"
      aria-label="Associação não é causa"
      data-testid="aviso-associacao"
    >
      <p class="font-semibold"><span aria-hidden="true">ℹ</span>{" "}Associação não é causa</p>
      {#each avisosAssociacao as a, i (i)}
        {#if a.mensagem}<p>{a.mensagem}</p>{/if}
      {/each}
    </div>
  {/if}

  {#each secoes as secao, i (i)}
    {#if secao.tipo === "texto"}
      <SecaoTexto {secao} />
    {:else if secao.tipo === "indicadores"}
      <SecaoIndicadores {secao} />
    {:else if secao.tipo === "tabela"}
      <SecaoTabela {secao} />
    {:else if secao.tipo === "grafico"}
      <SecaoGrafico {secao} />
    {:else if secao.tipo === "associacoes"}
      <SecaoAssociacoes {secao} />
    {/if}
  {/each}

  <footer class="border-t border-gray-200 pt-4 space-y-4 text-sm">
    {#if fontes.length}
      <section aria-labelledby="relatorio-fontes">
        <h3 id="relatorio-fontes" class="font-semibold text-gray-900">Fontes</h3>
        <ul class="mt-1 space-y-1 text-gray-600" data-testid="relatorio-fontes">
          {#each fontes as f, i (i)}
            <li>
              <!-- sem o nome interno da ferramenta: o gestor vê a descrição -->
              <span class="font-medium text-gray-800">{f.descricao ?? "Dados públicos"}</span>
              {#if f.edicao}{" · "}{f.edicao}{/if}
              {#if f.escopo}{" · "}{f.escopo}{/if}
              {#if f.n !== undefined && f.n !== null}{" · "}n = {formatarValor(f.n, "inteiro")}{/if}
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if avisos.length}
      <section aria-labelledby="relatorio-avisos">
        <h3 id="relatorio-avisos" class="font-semibold text-gray-900">Avisos</h3>
        <ul class="mt-1 space-y-1 text-amber-800" data-testid="relatorio-avisos">
          {#each avisos as a, i (i)}
            <li>{a.mensagem}</li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if relatorio?.rastreio}
      <p class="text-xs text-gray-400">
        Redação: {relatorio.rastreio.provedor ?? "—"}{#if relatorio.rastreio.modelo} / {relatorio.rastreio.modelo}{/if}
        {#if relatorio.rastreio.versao_edubr}{" · "}eduBR {relatorio.rastreio.versao_edubr}{/if}
      </p>
    {/if}
  </footer>
</article>
