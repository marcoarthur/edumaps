<script>
  // src/features/schools/components/profile/SchoolProfile.svelte
  //
  // Composição do "Perfil da Escola" (issue #105): diagnóstico +
  // posição relativa + benchmarking justo + sinais de atenção. Recebe o
  // objeto já transformado por transformProfileData().
  import AttentionFlags from './AttentionFlags.svelte';
  import ProfileComparison from './ProfileComparison.svelte';
  import ClusterSummary from './ClusterSummary.svelte';
  import ProfilePeers from './ProfilePeers.svelte';

  /**
   * @typedef {Object} Profile
   * @property {Object} school
   * @property {Object} cluster
   * @property {string} peersSourceLabel
   * @property {Array} indicadores
   * @property {Array} clusterResumo
   * @property {Array} peers
   * @property {Array} flags
   */
  /** @type {{ profile: Profile, onSelectPeer?: (id: string|number) => void }} */
  let { profile, onSelectPeer = () => {} } = $props();

  const inep = $derived(profile?.school?.co_entidade);
</script>

<div class="bg-white text-gray-900 p-6 rounded-lg flex flex-col gap-7 font-sans">
  <header class="flex flex-wrap justify-between items-end gap-4 border-b border-gray-200 pb-4">
    <div>
      <h1 class="text-2xl font-bold m-0">{profile.school.nome}</h1>
      <p class="text-sm text-gray-600 font-mono mt-1">
        {profile.school.municipio} · {profile.school.uf} · INEP {inep}
        {#if profile.school.anoCenso}· Censo {profile.school.anoCenso}{/if}
      </p>
      {#if profile.cluster.label}
        <span class="inline-flex items-center gap-1 mt-2 text-xs font-medium px-2 py-0.5 rounded-full bg-blue-50 text-blue-800 border border-blue-200">
          {profile.cluster.label}
        </span>
      {/if}
    </div>

    <div class="flex items-center gap-2">
      <a
        href={`/escola/panel?inep=${inep}`}
        class="px-3 py-2 text-sm font-medium rounded-md border border-gray-300 text-gray-700 hover:bg-gray-100 transition-colors whitespace-nowrap"
      >
        ← Painel da escola
      </a>
      <a
        href={`/escola/financeiro?inep=${inep}`}
        class="px-3 py-2 text-sm font-medium rounded-md border border-gray-300 text-gray-700 hover:bg-gray-100 transition-colors whitespace-nowrap"
      >
        Painel financeiro →
      </a>
    </div>
  </header>

  <AttentionFlags flags={profile.flags} />

  <ProfileComparison indicadores={profile.indicadores} />

  <ClusterSummary resumo={profile.clusterResumo} />

  <ProfilePeers
    peers={profile.peers}
    sourceLabel={profile.peersSourceLabel}
    onSelect={onSelectPeer}
  />
</div>
