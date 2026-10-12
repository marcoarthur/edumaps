<!-- src/features/gestor/components/envios/EnvioSelo.svelte -->
<script>
  // Selo do estado de um envio por e-mail (issue #216).
  import { seloEnvio } from "../../constants/envios.js";

  /** @type {{status: string}} */
  let { status } = $props();

  const selo = $derived(seloEnvio(status));
</script>

<span
  class={`inline-block px-2 py-0.5 rounded-full text-[11px] font-semibold whitespace-nowrap ${selo.classe}`}
  aria-label={`Estado: ${selo.rotulo}`}
  data-testid="envio-selo"
  data-status={status}
>{selo.rotulo}</span>
