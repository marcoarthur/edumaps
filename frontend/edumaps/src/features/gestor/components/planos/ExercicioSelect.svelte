<!-- src/features/gestor/components/planos/ExercicioSelect.svelte -->
<script>
  // Seletor de exercício dos custos (#404). "Todos os anos" é o padrão (null).
  // Os anos vêm do servidor (`exercicios`: anos dos prazos e das execuções);
  // o ano já escolhido fica na lista mesmo que não apareça nela. Não sai na
  // impressão: o documento impresso diz o exercício no título da seção.
  let { exercicio = null, exercicios = [], onchange } = $props();

  let anos = $derived([...new Set([...(exercicios ?? []), ...(exercicio ? [exercicio] : [])])].sort((a, b) => b - a));
</script>

<label class="text-xs text-gray-600 print:hidden"><span class="block">Exercício</span>
  <select value={exercicio ?? ""} onchange={(e) => onchange?.(e.currentTarget.value ? Number(e.currentTarget.value) : null)}
    class="mt-1 h-8 px-2 rounded-md border border-gray-300 text-sm bg-white">
    <option value="">Todos os anos</option>
    {#each anos as a (a)}<option value={a}>{a}</option>{/each}
  </select></label>
