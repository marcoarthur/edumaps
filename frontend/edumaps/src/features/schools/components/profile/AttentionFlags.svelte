<script>
  // src/features/schools/components/profile/AttentionFlags.svelte
  //
  // Sinais de atenção do perfil: indicadores em que a escola está no
  // quartil inferior do seu cluster (evita comparação injusta com
  // realidades distantes).
  import { SEVERIDADE_LABELS } from '../../utils/transformProfileData.js';
  import InfoHint from '@/shared/ui/components/InfoHint.svelte';

  let { flags = [] } = $props();

  const BADGE = {
    alta: 'bg-red-100 text-red-800 border-red-200',
    media: 'bg-amber-100 text-amber-800 border-amber-200',
    baixa: 'bg-yellow-50 text-yellow-800 border-yellow-200',
  };
</script>

<section class="flex flex-col gap-2" aria-label="Sinais de atenção">
  <div class="flex items-center gap-2">
    <h2 class="text-base font-bold text-gray-900">Sinais de atenção</h2>
    <InfoHint
      title="O que é um sinal de atenção"
      text="Indicadores em que a escola está no quartil inferior do seu cluster — comparação justa com escolas de contexto parecido."
      items={[
        'Regra (v1): valor no quartil inferior (Q1) do cluster gera atenção.',
        'A severidade indica a prioridade sugerida (alta/média/baixa).',
        'Não é julgamento absoluto: um indicador pode ser baixo no cluster e ainda aceitável no Brasil.',
        'Indicadores em que "menor é melhor" ainda usam a mesma regra nesta versão.',
      ]}
    />
  </div>

  {#if flags.length === 0}
    <p class="text-sm text-gray-500">
      Nenhum indicador no quartil inferior do cluster. 🎉
    </p>
  {:else}
    <ul class="flex flex-col gap-2">
      {#each flags as flag, i (flag.codigo ?? i)}
        <li class="flex items-start gap-3 bg-white border border-gray-200 rounded-md p-3">
          <span
            class="text-xs font-semibold px-2 py-0.5 rounded border whitespace-nowrap {BADGE[flag.severidade] ?? BADGE.media}"
          >
            {SEVERIDADE_LABELS[flag.severidade] ?? flag.severidade}
          </span>
          <div class="min-w-0">
            <p class="text-sm text-gray-800">{flag.mensagem}</p>
            {#if flag.label}
              <p class="text-xs text-gray-500 mt-0.5">{flag.label}</p>
            {/if}
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</section>
