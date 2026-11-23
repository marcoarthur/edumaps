<script>
  // src/features/schools/components/profile/AttentionFlags.svelte
  //
  // Sinais de atenção do perfil: indicadores em que a escola está no
  // quartil inferior do seu cluster (evita comparação injusta com
  // realidades distantes).
  import { SEVERIDADE_LABELS, fraseSinal } from '../../utils/transformProfileData.js';
  import InfoHint from '@/shared/ui/components/InfoHint.svelte';

  // #542: com a tabela comparada e o resumo do grupo, o sinal sai com os
  // números e em linguagem do dia a dia; sem eles, a mensagem do motor.
  let { flags = [], indicadores = [], clusterResumo = [], tamanhoGrupo = null } = $props();

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
      text="Indicadores em que a escola está pior que o seu grupo de referência — escolas do município de contexto parecido."
      items={[
        'Regra: a escola está entre o quarto pior do grupo (Q1 quando maior é melhor; Q4 quando menor é melhor, como em "sem formação continuada" e "aluno/docente") e pior que a mediana ("metade tem…").',
        'A frase compara também com o município e o Brasil: a escola pode estar atrás das parecidas e melhor que os dois.',
        'A severidade indica a prioridade sugerida (alta/média/baixa).',
        'Não é julgamento absoluto: um indicador pode ser baixo no grupo e ainda aceitável no Brasil.',
        'O INSE (nível socioeconômico) é contexto: aparece na comparação, mas não gera sinal.',
      ]}
    />
  </div>

  {#if flags.length === 0}
    <p class="text-sm text-gray-500">
      Nenhum indicador pior que o grupo de referência. 🎉
    </p>
  {:else}
    <ul class="flex flex-col gap-2">
      {#each flags as flag, i (flag.codigo ?? i)}
        {@const frase = fraseSinal(flag, indicadores, clusterResumo, tamanhoGrupo)}
        <li class="flex items-start gap-3 bg-white border border-gray-200 rounded-md p-3">
          <span
            class="text-xs font-semibold px-2 py-0.5 rounded border whitespace-nowrap {BADGE[flag.severidade] ?? BADGE.media}"
          >
            {SEVERIDADE_LABELS[flag.severidade] ?? flag.severidade}
          </span>
          <div class="min-w-0">
            {#if frase}
              <p class="text-sm text-gray-800" data-testid="sinal-{flag.indicador}">
                <strong>{frase.titulo}:</strong> {frase.texto}
              </p>
            {:else}
              <p class="text-sm text-gray-800" data-testid="sinal-{flag.indicador}">{flag.mensagem}</p>
            {/if}
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</section>
