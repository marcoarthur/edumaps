<script>
  // src/features/fontes/pages/FontesPage.svelte
  //
  // "Fontes e metodologia" (#428, AN-08): página pública com cada base das
  // análises — órgão, ano/período do dado, data da carga, arquivos com
  // SHA-256 — e as regras de leitura que valem para todas as telas.
  import { onMount } from "svelte";
  import { getFontes } from "../api/fontesApi.js";
  import { dataBR } from "../utils.js";

  let fontes = $state([]);
  let loading = $state(true);
  let error = $state(null);

  const TELAS = {
    comparacao_redes: "comparação de redes",
    perfil_escola: "perfil da escola",
    ranking: "ranking",
    agrupamento: "agrupamento de escolas",
    busca: "busca",
    financeiro: "financeiro da escola",
    folha: "folha de pagamento",
  };

  const tamanho = (b) =>
    b == null ? "" : b >= 1048576 ? `${(b / 1048576).toLocaleString("pt-BR", { maximumFractionDigits: 1 })} MB` : `${Math.round(b / 1024)} KB`;

  onMount(async () => {
    try {
      fontes = await getFontes();
    } catch {
      error = "Não foi possível carregar as fontes agora. Tente de novo em instantes.";
    } finally {
      loading = false;
    }
  });
</script>

<div class="space-y-6">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">Fontes e metodologia</h1>
    <p class="mt-1 text-sm text-gray-600">
      De onde vêm os números das análises públicas do EduMaps, de que ano são e quando foram carregados.
      Os anos e as datas abaixo são lidos da própria base, no momento em que você abre esta página.
    </p>
  </header>

  <section class="bg-white border border-gray-200 rounded-card shadow-card p-5" aria-labelledby="regras">
    <h2 id="regras" class="font-semibold text-gray-900">Como ler os números</h2>
    <ul class="mt-2 text-sm text-gray-700 list-disc pl-5 space-y-1">
      <li><strong>Ausência não é zero.</strong> "–" ou "n/d" quer dizer que a fonte não tem o dado; nunca é contado como zero.</li>
      <li><strong>Cada tela diz o ano.</strong> O selo "Fonte" no pé de cada análise diz a base, o ano do dado e a data da carga.</li>
      <li><strong>Perfil da escola:</strong> a escola é comparada com o seu grupo de escolas parecidas; um sinal de atenção só aparece quando ela está pior que a mediana do grupo, no sentido de cada indicador. O IDEB é o da etapa de maior nota da edição mais recente.</li>
      <li><strong>Agrupamento de escolas:</strong> cada resultado diz o seu universo (quantas escolas entraram e por que as outras ficaram de fora), tem link que o reabre por 90 dias e exportação em CSV com os parâmetros guardados.</li>
      <li><strong>Base de análise:</strong> a <a href="/base-analise" class="text-blue-700 hover:underline">base de análise</a> exporta os indicadores por escola de uma UF, com a versão dos dados em cada linha e um dicionário com a fonte de cada coluna.</li>
      <li><strong>Índices do EduMaps:</strong> os seis índices de 0 a 10 do ranking de escolas são calculados por nós, a partir do Censo Escolar. Cada mudança de fórmula ganha uma versão nova (ex.: <code>indices-v2</code>), que vai no CSV do ranking; notas de versões diferentes não são comparáveis.</li>
      <li><strong>Folha de pagamento:</strong> cobre só os municípios já carregados e só a rede municipal; a tela diz quais são.</li>
    </ul>
  </section>

  {#if loading}
    <p class="text-sm text-gray-500">Carregando as fontes…</p>
  {:else if error}
    <p class="text-sm text-red-700" role="alert">{error}</p>
  {:else}
    <div class="space-y-4">
      {#each fontes as f (f.id)}
        <article class="bg-white border border-gray-200 rounded-card shadow-card p-5" aria-labelledby="fonte-{f.id}" data-testid="fonte-{f.id}">
          <div class="flex flex-wrap items-baseline justify-between gap-2">
            <h2 id="fonte-{f.id}" class="font-semibold text-gray-900">{f.nome} <span class="text-gray-500 font-normal">· {f.orgao}</span></h2>
            {#if f.periodo?.texto}
              <span class="text-sm text-gray-700">Dado de <strong>{f.periodo.texto}</strong></span>
            {/if}
          </div>
          <p class="mt-1 text-sm text-gray-600">{f.descricao}</p>
          <dl class="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-1 text-sm">
            {#if f.proprio && f.versao}
              <div class="sm:col-span-2">
                <dt class="inline text-gray-500">Versão da fórmula:</dt>
                <dd class="inline text-gray-800"><strong data-testid="versao-{f.id}">{f.versao}</strong>, de {dataBR(f.data)}</dd>
              </div>
            {/if}
            <div>
              <dt class="inline text-gray-500">{f.proprio ? "Último cálculo:" : "Última carga:"}</dt>
              <dd class="inline text-gray-800">{f.carga?.data ? dataBR(f.carga.data) : "não registrada"}</dd>
            </div>
            {#if !f.proprio}
              <div>
                <dt class="inline text-gray-500">Licença:</dt>
                <dd class="inline text-gray-800">{f.licenca ?? "consulte os termos do órgão"}</dd>
              </div>
            {/if}
            {#if f.telas?.length}
              <div class="sm:col-span-2">
                <dt class="inline text-gray-500">Usada em:</dt>
                <dd class="inline text-gray-800">{f.telas.map((t) => TELAS[t] ?? t).join(", ")}</dd>
              </div>
            {/if}
          </dl>
          <p class="mt-2 text-sm flex flex-wrap gap-x-4">
            <a href={f.url} target="_blank" rel="noopener noreferrer" class="text-blue-700 hover:underline">{f.proprio ? "O que cada índice mede" : "Página oficial"}</a>
            {#if f.metodologia && f.metodologia !== f.url}
              <a href={f.metodologia} target="_blank" rel="noopener noreferrer" class="text-blue-700 hover:underline">{f.proprio ? "Fórmula completa" : "Metodologia do órgão"}</a>
            {/if}
          </p>
          {#if f.proprio && f.historico?.length}
            <details class="mt-2 text-xs text-gray-600" data-testid="historico-{f.id}">
              <summary class="cursor-pointer">Histórico das versões ({f.historico.length}). Para citar, informe a versão.</summary>
              <ul class="mt-1 space-y-1">
                {#each f.historico as h (h.versao)}
                  <li><strong class="text-gray-800">{h.versao}</strong> ({dataBR(h.data)}): {h.mudou}</li>
                {/each}
              </ul>
            </details>
          {/if}
          {#if f.carga?.arquivos?.length}
            <details class="mt-2 text-xs text-gray-600">
              <summary class="cursor-pointer">Arquivos da última carga ({f.carga.arquivos.length}), com SHA-256</summary>
              <ul class="mt-1 space-y-1">
                {#each f.carga.arquivos as a (a.sha256)}
                  <li class="break-all">
                    <a href={a.url} target="_blank" rel="noopener noreferrer" class="text-blue-700 hover:underline">{a.url.split("/").pop()}</a>
                    {tamanho(a.bytes)} · <code class="text-gray-800">{a.sha256}</code>
                  </li>
                {/each}
              </ul>
            </details>
          {/if}
        </article>
      {/each}
    </div>
  {/if}
</div>
