<script>
  // src/features/school/components/panel/SchoolSummary.svelte
  import Icon from '../icons/Icon.svelte';
  import { NETWORK_LABELS } from '../icons/icon-data.js';

  /**
   * @param {'municipal'|'state'|'private'} network - rede de ensino
   * @param {number} enrollments - total de matrículas (censo_matriculas.qt_mat_bas)
   */
  let { network, enrollments } = $props();

  // Faixas de porte — assumidas a partir de convenção comum de porte
  // escolar; ajustar com o time pedagógico se houver definição oficial.
  let size = $derived(
    enrollments == null ? null 
      : enrollments < 200 ? 'small'
      : enrollments < 700 ? 'medium'
      : 'large'
  );

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
        <em class="not-italic text-gray-500">
          · porte {size === 'small' ? 'pequena' : size === 'medium' ? 'média' : 'grande'}
        </em>
      </span>
    </span>
  {/if}
</div>
