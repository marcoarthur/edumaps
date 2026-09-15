<script>
  // src/shared/ui/components/Logo.svelte
  //
  // Marca do EduMaps: um pin de mapa (geolocalização) com um livro aberto
  // (educação) e três barras ascendentes (censo / análise) vazados.
  // Glifo vetorial único (viewBox fixo) — escala para qualquer tamanho
  // (favicon 16px, header 28px, hero 80px) mantendo o traço legível.
  //
  // variant:
  //   "brand" -> pin azul sobre fundo claro (padrão)
  //   "light" -> pin branco para uso sobre superfícies escuras (nav)
  let { size = 32, title = "EduMaps", variant = "brand" } = $props();

  const PALETTE = {
    brand: { pin: "#1e40af", detail: "#ffffff" },
    light: { pin: "#ffffff", detail: "#1e40af" },
  };
  let colors = $derived(PALETTE[variant] ?? PALETTE.brand);
</script>

<svg
  xmlns="http://www.w3.org/2000/svg"
  viewBox="0 0 48 48"
  width={size}
  height={size}
  role="img"
  aria-label={title}
>
  <title>{title}</title>

  <!-- Pin de mapa -->
  <path
    fill={colors.pin}
    d="M24 3.5C14.335 3.5 6.5 11.335 6.5 21c0 7.2 4.8 13.2 10 18 3.5 3.2 6.2 5.4 7.5 6.5 1.3-1.1 4-3.3 7.5-6.5 5.2-4.8 10-10.8 10-18C41.5 11.335 33.665 3.5 24 3.5Z"
  />

  <!-- Livro aberto (educação) -->
  <g fill={colors.detail}>
    <path d="M24 11.5c-2.5-1.5-6-1.9-8.7-1l0 8.1c2.7-.9 6.2-.5 8.7 1z" />
    <path d="M24 11.5c2.5-1.5 6-1.9 8.7-1l0 8.1c-2.7-.9-6.2-.5-8.7 1z" />
  </g>
  <line
    x1="24"
    y1="11.9"
    x2="24"
    y2="19.2"
    stroke={colors.pin}
    stroke-width="0.9"
    stroke-linecap="round"
  />

  <!-- Barras ascendentes (censo / análise) -->
  <g fill={colors.detail}>
    <rect x="17" y="28" width="3" height="3.5" rx="1" />
    <rect x="21.5" y="26" width="3" height="5.5" rx="1" />
    <rect x="26" y="24" width="3" height="7.5" rx="1" />
  </g>
</svg>
