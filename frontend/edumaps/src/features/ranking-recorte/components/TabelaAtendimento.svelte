<script>
  // src/features/ranking-recorte/components/TabelaAtendimento.svelte
  //
  // #535 (QO-01 da P5): taxa de atendimento da educação infantil por
  // município no ranking de redes. A posição é pela taxa de todas as redes
  // (a conta da meta 1 do PNE), da menor para a maior.
  import { num } from "../utils/formato.js";
  import { rotuloPorte, rotuloRegiao } from "../constants.js";

  let { redes, linhas = [], destaque = null, multiUf = false, onExportar } = $props();

  const pct = (v) => (v == null ? "–" : `${(v * 100).toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`);
  const meta = $derived(redes.meta?.valor ?? null);
  const temTeto = $derived(linhas.some((l) => l.teto != null));
</script>

<div class="flex flex-wrap items-start justify-between gap-3">
  <p class="text-xs text-gray-600 max-w-3xl" data-testid="nota-atendimento">
    <!-- #549 (QJ-01 da P5): a conta pelo nome, e que não é o indicador oficial -->
    <strong>Taxa bruta de matrícula</strong> = matrículas na {redes.indicador.etapa === "creche" ? "creche" : "pré-escola"}
    (de qualquer idade e de qualquer município) ÷ crianças de {redes.indicador.idade} que moram no município.
    <span data-testid="aviso-oficial">Não é o indicador oficial da meta 1 do PNE, que mede o percentual das crianças da idade que frequentam creche ou escola, em pesquisa domiciliar: os números podem diferir.</span>
    A posição é pela conta de <strong>todas as redes</strong>, comparada à meta 1 do PNE
    ({redes.indicador.etapa === "creche" ? "50% das crianças de 0 a 3 anos" : "todas as crianças de 4 e 5 anos"}),
    da menor taxa para a maior.
    <strong data-testid="abaixo-meta">{redes.meta.abaixo.toLocaleString("pt-BR")} de {redes.total.toLocaleString("pt-BR")}
      {redes.total === 1 ? "município" : "municípios"}</strong> neste recorte estão abaixo de {pct(meta).replace(",0", "")}.
    {#if redes.meta?.vagas_faltam > 0}
      <!-- #547: quanto falta, em vagas, somando os municípios abaixo da meta -->
      <span data-testid="vagas-recorte">Para todos chegarem a {pct(meta).replace(",0", "")}, faltam, por esta conta, cerca de
        <strong>{redes.meta.vagas_faltam.toLocaleString("pt-BR")} vagas</strong> no recorte (a estimativa de cada município está
        no CSV e na comparação de redes).</span>
    {/if}
    A rede do município sozinha e somada às escolas privadas conveniadas com a prefeitura (um teto: o Censo marca a
    escola conveniada, não a vaga) vêm ao lado.
    Crianças do Censo Demográfico {redes.ano} (IBGE), matrículas das escolas em funcionamento no Censo Escolar
    {redes.ano_censo ?? ""}. A taxa pode passar de 100%: entram crianças de outros municípios e fora da idade, e a
    população mudou desde o Censo. Município com poucas crianças tem taxa instável.
    No Distrito Federal, que não tem prefeitura, a rede do município é a distrital, e as conveniadas são com o governo distrital.
    {#if redes.recorte?.regiao}
      Só os municípios da região {redes.recorte.regiao.nome ?? rotuloRegiao(redes.recorte.regiao.id)}.
    {/if}
    {#if redes.recorte?.porte}
      Só os municípios com {rotuloPorte(redes.recorte.porte).replace(" hab.", " habitantes").toLowerCase()}.
    {/if}
  </p>
  <button type="button" onclick={onExportar}
    class="px-3 py-1.5 text-sm rounded-md bg-blue-700 text-white hover:bg-blue-800">Baixar CSV</button>
</div>
<div class="overflow-x-auto">
  <table class="w-full text-sm" data-testid="tabela-atendimento">
    <thead>
      <tr class="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100">
        <th class="px-2 py-2 font-medium">#</th>
        <th class="px-2 py-2 font-medium">Município</th>
        <th class="px-2 py-2 font-medium text-right">Crianças ({redes.indicador.idade})</th>
        <th class="px-2 py-2 font-medium text-right">Todas as redes</th>
        <th class="px-2 py-2 font-medium text-right">Rede do município</th>
        {#if temTeto}
          <th class="px-2 py-2 font-medium text-right">Rede do município + conveniadas (teto)</th>
        {/if}
        <th class="px-2 py-2 font-medium text-right">População</th>
      </tr>
    </thead>
    <tbody>
      {#each linhas as r (r.codigo_ibge)}
        <tr id="rede-{r.codigo_ibge}"
          class="border-b border-gray-50 {destaque && r.codigo_ibge === destaque.codigo_ibge ? 'bg-yellow-50 font-semibold' : ''}"
          data-testid={destaque && r.codigo_ibge === destaque.codigo_ibge ? "linha-destaque" : undefined}
          aria-current={destaque && r.codigo_ibge === destaque.codigo_ibge ? "true" : undefined}>
          <td class="px-2 py-1.5 text-gray-500">{r.posicao}</td>
          <td class="px-2 py-1.5">
            <a href="/municipio/compare?codigo_ibge={r.codigo_ibge}" class="text-blue-700 hover:underline">{r.municipio}</a>
            {#if multiUf}<span class="text-gray-400"> · {r.uf}</span>{/if}
          </td>
          <td class="px-2 py-1.5 text-right">{num(r.criancas, 0)}</td>
          <td class="px-2 py-1.5 text-right font-medium whitespace-nowrap">
            {pct(r.taxa)}
            {#if r.abaixo_meta}
              <span class="ml-1 inline-block px-1.5 py-0.5 rounded bg-amber-50 text-amber-800 text-[11px] font-medium"
                data-testid="abaixo-da-meta" title="Abaixo de {pct(meta)} pela taxa bruta de matrícula">abaixo de {pct(meta).replace(",0", "")}</span>
            {/if}
          </td>
          <td class="px-2 py-1.5 text-right whitespace-nowrap">
            {pct(r.taxa_municipal)}
            {#if r.rede_local === "distrital"}
              <!-- #545: no DF não há prefeitura; a rede local é a distrital -->
              <span class="ml-1 text-[11px] text-gray-500" data-testid="rede-distrital"
                title="No Distrito Federal a rede do ente local é a distrital, e as conveniadas são com o governo distrital.">distrital</span>
            {/if}
          </td>
          {#if temTeto}
            <td class="px-2 py-1.5 text-right">{pct(r.teto)}</td>
          {/if}
          <td class="px-2 py-1.5 text-right whitespace-nowrap" title={rotuloPorte(r.porte)}>{num(r.populacao, 0)}</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
