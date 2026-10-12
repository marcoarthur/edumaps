<!-- src/features/gestor/components/envios/LimitesPainel.svelte -->
<script>
  // Painel de limites do envio por e-mail (issue #216): saldo do dia, cota,
  // teto por envio e avisos (escola suspensa, envio desligado, SMTP fora).
  import { formatarDataHora } from "../../constants/envios.js";

  /** @type {{limites: object|null, carregando?: boolean}} */
  let { limites = null, carregando = false } = $props();
</script>

<section
  class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-3"
  aria-label="Limites de envio"
  data-testid="limites-envio"
>
  {#if carregando && !limites}
    <p class="text-sm text-gray-500">Carregando limites…</p>
  {:else if limites}
    <dl class="grid grid-cols-2 sm:grid-cols-4 gap-3 text-sm">
      <div>
        <dt class="text-xs text-gray-500">Saldo de hoje</dt>
        <dd class="text-lg font-semibold text-gray-900" data-testid="saldo-hoje">{limites.saldo_hoje}</dd>
      </div>
      <div>
        <dt class="text-xs text-gray-500">Enviados hoje</dt>
        <dd class="text-lg font-semibold text-gray-900">{limites.enviados_hoje}</dd>
      </div>
      <div>
        <dt class="text-xs text-gray-500">Cota diária</dt>
        <dd class="text-lg font-semibold text-gray-900">{limites.cota_diaria}</dd>
      </div>
      <div>
        <dt class="text-xs text-gray-500">Máx. por envio</dt>
        <dd class="text-lg font-semibold text-gray-900">{limites.max_destinatarios}</dd>
      </div>
    </dl>

    {#if limites.suspensao}
      <p class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-3" role="alert" data-testid="aviso-suspensao">
        Os envios desta escola estão suspensos desde {formatarDataHora(limites.suspensao.suspenso_em)}.
        {#if limites.suspensao.motivo}Motivo: {limites.suspensao.motivo}.{/if}
        Fale com a administração da plataforma.
      </p>
    {/if}
    {#if limites.enabled === false}
      <p class="rounded-md bg-amber-50 border border-amber-200 text-amber-800 text-sm p-3" role="alert" data-testid="aviso-desligado">
        O envio de e-mails está desligado pela administração da plataforma.
      </p>
    {/if}
    {#if limites.smtp_disponivel === false}
      <p class="rounded-md bg-amber-50 border border-amber-200 text-amber-800 text-sm p-3" role="alert" data-testid="aviso-smtp">
        O e-mail da plataforma não está disponível agora. Você pode preparar rascunhos, mas não enviar.
      </p>
    {/if}
  {/if}
</section>
