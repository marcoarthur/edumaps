<!-- src/features/inscricao/components/LinkExclusao.svelte -->
<script>
  // Link "Remover meus dados" (issue #214): o backend devolve `exclusao_url` em
  // toda inscrição real; é a única chave que o titular tem para pedir a
  // remoção, por isso orientamos a guardá-lo.
  /** @type {{url?: string|null}} */
  let { url = null } = $props();
</script>

{#if url}
  <div
    class="mt-4 rounded-md border border-gray-200 bg-gray-50 p-3 text-left space-y-1"
    data-testid="link-exclusao"
  >
    <a
      href={url}
      class="text-sm font-semibold text-blue-700 underline break-all"
    >Remover meus dados</a>
    <p class="text-xs text-gray-600">
      Guarde este link (salve nos favoritos ou tire um print): com ele você pode pedir,
      a qualquer momento, que a escola apague seus dados desta lista.
    </p>
  </div>
{/if}
