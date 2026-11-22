<script>
  // src/features/network-compare/pages/NetworkProfilePage.svelte
  //
  // Perfil analítico da rede de um município (issue #109): indicadores da
  // rede vs. Brasil e distribuição das escolas por cluster.
  // Rota: /municipio/perfil?codigo_ibge=XXXXXXX[&dependencia=N]. O mesmo
  // parâmetro da comparação de redes (#431); o `?ibge=` antigo continua
  // aceito para não quebrar links já compartilhados.
  import { onMount } from "svelte";
  import { getNetworkProfile } from "../api/networkCompareApi.js";
  import {
    transformNetworkProfileData,
    formatNetworkValue,
    formatNetworkVariacao,
    rotuloIndicadorRede,
  } from "../utils/transformNetworkProfileData.js";
  import { diferencaFavoravel, sentidoIndicador } from "@/shared/utils/sentidoIndicador.js";

  // #421: a cor segue o sentido do indicador (em "sem formação continuada" e
  // "aluno/docente", ficar abaixo do Brasil é bom).
  function corVariacao(ind) {
    const f = diferencaFavoravel(ind.indicador, ind.variacao);
    if (f === null) return "text-gray-500";
    return f ? "text-emerald-700" : "text-red-700";
  }
  import { networkCompareUrl } from "../utils/transformNetworkData.js";
  import InfoHint from "@/shared/ui/components/InfoHint.svelte";
  import { ApiError } from "@/shared/api/client.js";

  let ibge = $state(null);
  let profile = $state(null);
  let loading = $state(true);
  let error = $state(null);

  async function load(codigoIbge, tpDependencia) {
    loading = true;
    error = null;
    try {
      const raw = await getNetworkProfile(codigoIbge, { tpDependencia });
      profile = transformNetworkProfileData(raw);
    } catch (err) {
      profile = null;
      error =
        err instanceof ApiError
          ? err.message
          : "Erro ao carregar o perfil da rede.";
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    const params = new URLSearchParams(window.location.search);
    const code = params.get("codigo_ibge") ?? params.get("ibge");
    const dep = params.get("dependencia");
    if (code) {
      ibge = code;
      load(code, dep ? Number(dep) : undefined);
    } else {
      loading = false;
      error = "Nenhum código IBGE informado (?codigo_ibge=XXXXXXX).";
    }
  });

  function goBack() {
    window.location.href = ibge ? networkCompareUrl(ibge) : "/";
  }
</script>

<div class="space-y-6">
  <header class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Perfil da Rede</h1>
      {#if profile}
        <p class="text-sm text-gray-600 mt-1">
          {profile.metadata.municipio} · {profile.metadata.uf}
          {#if profile.metadata.dependenciaLabel}· {profile.metadata.dependenciaLabel}{/if}
          · {profile.metrics.n_escolas ?? "–"} escolas
          {#if profile.metadata.anoCenso}· Censo {profile.metadata.anoCenso}{/if}
        </p>
      {/if}
    </div>
    <button
      onclick={goBack}
      class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300 transition-colors"
    >
      ← Voltar
    </button>
  </header>

  {#if loading}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando o perfil da rede…</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      {error}
    </div>
  {:else if profile}
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <section aria-label="Rede vs. Brasil" class="flex flex-col gap-2">
        <div class="flex items-center gap-2">
          <h2 class="text-base font-bold text-gray-900">Rede vs. Brasil</h2>
          <InfoHint
            title="Como comparamos a rede"
            text="Cada indicador é a média simples das escolas ativas do recorte (município e, se filtrado, a dependência) que têm o dado, comparada à média do Brasil da mesma rede."
            items={[
              'Com uma rede escolhida, o Brasil é o da mesma rede (por exemplo, só as redes municipais do país); sem filtro, todas as redes. A coluna diz qual.',
              'Escolas com dado: em quantas escolas a média se apoia. O IDEB, o SAEB e o INSE só existem em parte das escolas (as privadas não têm).',
              'IDEB e SAEB: uma linha por etapa (anos iniciais, anos finais, ensino médio), cada uma comparada com o Brasil na mesma etapa. A escala do SAEB cresce com a série e o IDEB cai: etapas diferentes não se comparam.',
              'Fonte: Censo Escolar, IDEB/SAEB e INSE — edição mais recente.',
              'A média do Brasil vem da referência pré-computada (mesma base do perfil da escola) ou é calculada na hora.',
              'Variação = rede − Brasil (positivo = acima da média nacional; proporções em pontos percentuais, p.p.).',
              'Verde = melhor que o Brasil, vermelho = pior, conforme o sentido do indicador: em "sem formação continuada" e "aluno/docente", menor é melhor.',
            ]}
          />
        </div>
        <p class="text-xs text-gray-600" data-testid="referencia-rotulo">
          Comparada com: <strong>{profile.metadata.referenciaRotulo}</strong>{#if profile.metadata.nBrasil}{" "}({profile.metadata.nBrasil.toLocaleString("pt-BR")} escolas){/if}
        </p>
        <div class="overflow-x-auto border border-gray-200 rounded-md">
          <table class="min-w-full text-sm">
            <thead class="bg-gray-50 text-gray-600">
              <tr>
                <th class="text-left font-semibold px-3 py-2">Indicador</th>
                <th class="text-right font-semibold px-3 py-2">Rede</th>
                <th class="text-right font-semibold px-3 py-2">{profile.metadata.referenciaRotulo}</th>
                <th class="text-right font-semibold px-3 py-2">Variação</th>
                <th class="text-right font-semibold px-3 py-2">Escolas com dado</th>
              </tr>
            </thead>
            <tbody>
              {#each profile.indicadores as ind (ind.indicador)}
                <tr class="bg-white">
                  <td class="text-left px-3 py-2 text-gray-800">
                    {rotuloIndicadorRede(ind, profile.metadata)}
                    {#if sentidoIndicador(ind.indicador) === "menor"}
                      <span class="block text-xs text-gray-500">menor é melhor</span>
                    {/if}
                  </td>
                  <td class="text-right px-3 py-2 font-mono text-gray-700">{formatNetworkValue(ind.indicador, ind.rede)}</td>
                  <td class="text-right px-3 py-2 font-mono text-gray-500">{formatNetworkValue(ind.indicador, ind.brasil)}</td>
                  <td class="text-right px-3 py-2 font-mono whitespace-nowrap {corVariacao(ind)}">
                    {formatNetworkVariacao(ind.indicador, ind.variacao)}
                  </td>
                  <td class="text-right px-3 py-2 font-mono text-gray-500">
                    {ind.nComValor == null ? "–" : ind.nComValor.toLocaleString("pt-BR")}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </section>

      <section aria-label="Distribuição por nível socioeconômico" class="flex flex-col gap-2">
        <div class="flex items-center gap-2">
          <h2 class="text-base font-bold text-gray-900">Distribuição por nível socioeconômico (INSE)</h2>
          <InfoHint
            title="Como os grupos dividem a rede"
            text="As escolas do recorte divididas pelo nível socioeconômico dos alunos (INSE), na classificação publicada pelo INEP, com a média de cada indicador por nível."
            items={[
              'Nível I é o mais baixo, Nível VIII o mais alto. As faixas são do INEP e valem para todo o país: o mesmo nível quer dizer o mesmo contexto em qualquer município.',
              '"Sem INSE" reúne as escolas sem o indicador: as privadas e a maior parte das creches e pré-escolas.',
              'Médias por indicador calculadas sobre as escolas do nível que têm o dado.',
            ]}
          />
        </div>
        {#if profile.metadata.grupoCriterio}
          <p class="text-xs text-gray-600" data-testid="grupo-criterio">{profile.metadata.grupoCriterio}</p>
        {/if}
        <div class="flex flex-col gap-4">
          {#each profile.clusters as cluster (cluster.cluster_label + '::' + (cluster.cluster_id ?? 'sem'))}
            <article class="bg-white border border-gray-200 rounded-md p-3 flex flex-col gap-2">
              <header class="flex items-baseline justify-between gap-2">
                <strong class="text-sm text-gray-900">{cluster.cluster_label}</strong>
                <span class="text-xs text-gray-500">{cluster.n} escolas</span>
              </header>
              <ul class="grid grid-cols-2 gap-x-4 gap-y-1">
                {#each cluster.indicadores as ind (ind.indicador)}
                  <li class="flex justify-between gap-2 text-xs">
                    <span class="text-gray-600 truncate" title={rotuloIndicadorRede(ind, profile.metadata)}>
                      {ind.label}{#if ind.nComValor != null && ind.nComValor < cluster.n}
                        <span class="text-gray-400"> ({ind.nComValor})</span>{/if}
                    </span>
                    <span class="font-mono text-gray-700 whitespace-nowrap">
                      {formatNetworkValue(ind.indicador, ind.media)}
                    </span>
                  </li>
                {/each}
              </ul>
            </article>
          {/each}
        </div>

        <p class="text-xs text-gray-500">
          Cada grupo mostra o nº de escolas e a média do indicador entre elas. Entre parênteses,
          quando nem todas têm o dado, em quantas a média se apoia.
        </p>
      </section>
    </div>
  {/if}
</div>
