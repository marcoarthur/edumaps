<!-- src/features/inscricao/components/TermoConsentimento.svelte -->
<script>
  // Texto de consentimento vigente (issue #214), expansível e com a versão
  // visível. O markdown simples vira elementos próprios (sem {@html}).
  import TextoMarkdown from "./TextoMarkdown.svelte";

  /** @type {{consentimento: {versao: string, texto: string}, aberto?: boolean}} */
  let { consentimento, aberto = $bindable(false) } = $props();
</script>

<details
  class="rounded-md border border-gray-200 bg-gray-50"
  data-testid="termo-consentimento"
  bind:open={aberto}
>
  <summary class="cursor-pointer px-3 py-2 text-sm font-medium text-gray-700">
    Ler o termo de consentimento
    <span class="text-xs text-gray-500" data-testid="termo-versao">(versão {consentimento.versao})</span>
  </summary>
  <div class="px-3 pb-3 space-y-2 text-sm text-gray-700" data-testid="termo-texto">
    <TextoMarkdown texto={consentimento?.texto} />
  </div>
</details>
