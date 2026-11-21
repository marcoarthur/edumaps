<script>
  // src/features/school/components/panel/SchoolSummary.svelte
  import Icon from '../icons/Icon.svelte';
  import { NETWORK_LABELS } from '../icons/icon-data.js';

  /**
   * @param {'municipal'|'estadual'|'privada'} network - rede de ensino
   * @param {number|null} enrollments - total de matrículas da educação básica
   *   (censo_matriculas.qt_mat_bas, #510)
   * @param {number|null} anoCenso - ano do Censo das matrículas
   *
   * #510 (RA-02): sem o "porte" da escola. As faixas (200/700) tinham sido
   * assumidas, sem fonte; não há classificação oficial de porte da escola.
   */
  let { network, enrollments, anoCenso = null } = $props();

  // Mapeamento de cores (ajuste conforme tema)
  const networkColorMap = {
    municipal: '#2563EB', // blue-600
    estadual: '#7C3AED',     // purple-600
    privada: '#059669',   // emerald-600
  };
  const networkColor = networkColorMap[network] || '#6B7280';
</script>

<div class="flex items-center gap-5 flex-wrap">
  {#if network}
    <span 
      class="inline-block text-sm font-semibold px-3 py-1 rounded-full border"
      style="color: {networkColor}; background-color: {networkColor}18; border-color: {networkColor};"
    >
      Rede {NETWORK_LABELS[network] ?? network}
    </span>
  {/if}

  {#if enrollments != null}
    <span class="flex items-center gap-2 text-sm text-gray-900">
      <Icon name="matriculas" size={30} active={true} />
      <span>
        <strong class="font-mono">{enrollments.toLocaleString('pt-BR')}</strong> matrículas
        {#if anoCenso}
          <em class="not-italic text-gray-500" data-testid="matriculas-ano">(Censo {anoCenso})</em>
        {/if}
      </span>
    </span>
  {/if}
</div>
