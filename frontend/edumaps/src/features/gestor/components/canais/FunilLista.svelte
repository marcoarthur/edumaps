<!-- src/features/gestor/components/canais/FunilLista.svelte -->
<script>
  // Funil de uma lista (issue #216, onda 2): acessos ao QR → inscrições →
  // confirmados, mais as saídas dos envios, no período escolhido (7/30/90
  // dias até hoje, em America/Sao_Paulo). Cartões com totais e taxas
  // ("—" quando o backend devolve null) e barras por dia em SVG puro, uma
  // métrica por vez; cada barra tem dica (title) e há uma tabela para leitores
  // de tela com a série completa.
  import { getFunil } from "../../api/gestorCanaisApi.js";
  import { ApiError } from "@/shared/api/client.js";

  /**
   * @type {{
   *   inep: string|number,
   *   listaId: number,
   *   hoje?: string|null,
   *   onSessaoExpirada?: () => void,
   * }}
   */
  let { inep, listaId, hoje = null, onSessaoExpirada = () => {} } = $props();

  const PERIODOS = [7, 30, 90];
  const METRICAS = [
    { valor: "acessos", rotulo: "Acessos ao QR" },
    { valor: "inscricoes", rotulo: "Inscrições" },
    { valor: "confirmados", rotulo: "Confirmados" },
    { valor: "optouts", rotulo: "Saídas" },
  ];

  let periodo = $state(30);
  let metrica = $state("acessos");
  let dados = $state(null);
  let carregando = $state(false);
  let erro = $state(null);

  const hojeSaoPaulo = () =>
    new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(new Date());

  function somarDias(dia, n) {
    const d = new Date(`${dia}T12:00:00Z`);
    d.setUTCDate(d.getUTCDate() + n);
    return d.toISOString().slice(0, 10);
  }

  const diaBr = (dia) => (dia ? dia.split("-").reverse().join("/") : "—");
  const numero = (v) => (v == null ? "—" : Number(v).toLocaleString("pt-BR"));
  const pct = (v) =>
    v == null
      ? "—"
      : `${(Number(v) * 100).toLocaleString("pt-BR", { maximumFractionDigits: 1 })}%`;

  async function carregar(dias) {
    const ate = hoje || hojeSaoPaulo();
    const de = somarDias(ate, -(dias - 1));
    carregando = true;
    erro = null;
    try {
      dados = await getFunil(inep, listaId, { de, ate });
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        onSessaoExpirada();
        return;
      }
      erro = err instanceof ApiError ? err.message : "Não foi possível carregar o funil.";
    } finally {
      carregando = false;
    }
  }

  // recarrega ao trocar de lista ou de período
  $effect(() => {
    const dias = periodo;
    void listaId;
    carregar(dias);
  });

  const serie = $derived(dados?.serie ?? []);
  const metricaNula = $derived(dados?.totais?.[metrica] == null && dados != null);
  const maxReal = $derived(Math.max(0, ...serie.map((s) => Number(s[metrica]) || 0)));
  const maximo = $derived(Math.max(1, maxReal));
  const rotuloMetrica = $derived(METRICAS.find((m) => m.valor === metrica)?.rotulo ?? metrica);

  // geometria do gráfico (unidades do viewBox)
  const ALTURA = 100;
  const PASSO = 10;
  const LARGURA_BARRA = 7;

  const cartoes = $derived(
    dados
      ? [
          { chave: "acessos", rotulo: "Acessos ao QR", valor: numero(dados.totais?.acessos) },
          { chave: "inscricoes", rotulo: "Inscrições", valor: numero(dados.totais?.inscricoes) },
          {
            chave: "confirmados",
            rotulo: "Confirmados",
            valor: numero(dados.totais?.confirmados),
            nota: dados.totais?.confirmados == null ? "lista não exige confirmação" : null,
          },
          { chave: "optouts", rotulo: "Saídas", valor: numero(dados.totais?.optouts) },
          {
            chave: "taxa-acesso-inscricao",
            rotulo: "Acesso → inscrição",
            valor: pct(dados.taxas?.acesso_inscricao),
          },
          {
            chave: "taxa-inscricao-confirmacao",
            rotulo: "Inscrição → confirmação",
            valor: pct(dados.taxas?.inscricao_confirmacao),
          },
        ]
      : [],
  );
</script>

<section class="space-y-3" data-testid="funil-lista">
  <div class="flex flex-wrap items-center justify-between gap-2">
    <p class="text-xs text-gray-600">
      {#if dados}Período: {diaBr(dados.de)} a {diaBr(dados.ate)}{/if}
    </p>
    <div class="flex items-center gap-1" role="group" aria-label="Período do funil">
      {#each PERIODOS as p (p)}
        <button
          type="button"
          aria-pressed={periodo === p}
          onclick={() => (periodo = p)}
          class="px-2.5 py-1 rounded-md text-xs font-medium border transition-colors {periodo === p
            ? 'bg-indigo-600 border-indigo-600 text-white'
            : 'bg-white border-gray-300 text-gray-700 hover:bg-gray-50'}"
        >{p} dias</button>
      {/each}
    </div>
  </div>

  {#if erro}
    <p class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-3" role="alert">{erro}</p>
  {:else if carregando && !dados}
    <p class="text-sm text-gray-500">Carregando funil…</p>
  {:else if dados}
    <dl class="grid grid-cols-2 sm:grid-cols-3 gap-3" data-testid="funil-cartoes">
      {#each cartoes as c (c.chave)}
        <div class="rounded-md bg-white border border-gray-200 p-3">
          <dt class="text-[11px] text-gray-500">{c.rotulo}</dt>
          <dd class="text-lg font-semibold text-gray-900" data-testid={`funil-${c.chave}`}>{c.valor}</dd>
          {#if c.nota}<dd class="text-[11px] text-gray-400">{c.nota}</dd>{/if}
        </div>
      {/each}
    </dl>

    <div class="rounded-md bg-white border border-gray-200 p-3 space-y-2">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h3 class="text-xs font-semibold text-gray-700">{rotuloMetrica} por dia</h3>
        <div class="flex flex-wrap gap-1" role="group" aria-label="Métrica do gráfico">
          {#each METRICAS as m (m.valor)}
            <button
              type="button"
              aria-pressed={metrica === m.valor}
              onclick={() => (metrica = m.valor)}
              class="px-2 py-0.5 rounded text-[11px] border transition-colors {metrica === m.valor
                ? 'bg-gray-800 border-gray-800 text-white'
                : 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'}"
            >{m.rotulo}</button>
          {/each}
        </div>
      </div>

      {#if metricaNula}
        <p class="text-xs text-gray-500 py-6 text-center" data-testid="funil-sem-metrica">
          Esta lista não exige confirmação; não há confirmados para mostrar.
        </p>
      {:else}
        <svg
          viewBox={`0 0 ${Math.max(serie.length, 1) * PASSO} ${ALTURA}`}
          preserveAspectRatio="none"
          class="w-full h-32"
          role="img"
          aria-label={`${rotuloMetrica} por dia, de ${diaBr(dados.de)} a ${diaBr(dados.ate)}: total ${numero(dados.totais?.[metrica])}, máximo diário ${numero(maxReal)}.`}
          data-testid="funil-grafico"
        >
          <line x1="0" y1={ALTURA - 0.5} x2={serie.length * PASSO} y2={ALTURA - 0.5} class="stroke-gray-200" stroke-width="1" vector-effect="non-scaling-stroke" />
          {#each serie as s, i (s.dia)}
            {@const v = Number(s[metrica]) || 0}
            {@const h = (v / maximo) * (ALTURA - 4)}
            <g data-testid="funil-barra">
              <title>{diaBr(s.dia)}: {numero(s[metrica])} {rotuloMetrica.toLowerCase()}</title>
              <rect x={i * PASSO} y="0" width={PASSO} height={ALTURA} fill="transparent" />
              {#if v > 0}
                <rect
                  x={i * PASSO + (PASSO - LARGURA_BARRA) / 2}
                  y={ALTURA - h}
                  width={LARGURA_BARRA}
                  height={h}
                  rx="1"
                  class="fill-indigo-500"
                />
              {/if}
            </g>
          {/each}
        </svg>
        <div class="flex justify-between text-[10px] text-gray-400" aria-hidden="true">
          <span>{diaBr(dados.de)}</span>
          <span>máx. {numero(maxReal)}/dia</span>
          <span>{diaBr(dados.ate)}</span>
        </div>
      {/if}

      <table class="sr-only" data-testid="funil-tabela">
        <caption>Funil por dia</caption>
        <thead>
          <tr>
            <th scope="col">Dia</th>
            <th scope="col">Acessos ao QR</th>
            <th scope="col">Inscrições</th>
            <th scope="col">Confirmados</th>
            <th scope="col">Saídas</th>
          </tr>
        </thead>
        <tbody>
          {#each serie as s (s.dia)}
            <tr>
              <th scope="row">{diaBr(s.dia)}</th>
              <td>{numero(s.acessos)}</td>
              <td>{numero(s.inscricoes)}</td>
              <td>{numero(s.confirmados)}</td>
              <td>{numero(s.optouts)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</section>
