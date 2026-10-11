<!-- src/features/privacidade/pages/PrivacidadePage.svelte -->
<script>
  // Página pública de política de privacidade (rota /privacidade). Existe para
  // dar base informada ao consentimento da autoinscrição por QR (issue #208):
  // o formulário público aponta para cá. Texto mínimo e factual da Fase 0 —
  // a redação definitiva é responsabilidade da escola/revisão jurídica.
  const retencao = [
    "Nome e telefone são usados apenas para a escola entrar em contato.",
    "Os dados ficam restritos à escola e não são compartilhados com terceiros.",
    "A inscrição pode ser removida a pedido, falando com a escola.",
  ];
</script>

<article class="max-w-3xl mx-auto space-y-8">
  <header>
    <h1 class="text-3xl font-bold text-gray-900">Política de Privacidade</h1>
    <p class="mt-2 text-gray-600">
      Como o EduMaps trata dados no contexto da autoinscrição por QR code e do
      uso geral da plataforma.
    </p>
  </header>

  <section class="bg-white border border-gray-200 rounded-card shadow-card p-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-3">Autoinscrição em listas</h2>
    <p class="text-gray-700 leading-relaxed">
      Ao preencher o formulário aberto pelo QR code, você informa seu
      <strong>nome</strong> e <strong>telefone</strong>. Esses dados são gravados
      para que a escola possa entrar em contato com você.
    </p>
    <ul class="mt-4 space-y-2">
      {#each retencao as item}
        <li class="flex gap-2 text-gray-700">
          <span class="text-brand-600 font-bold">→</span>
          <span>{item}</span>
        </li>
      {/each}
    </ul>
    <p class="mt-4 text-sm text-gray-500">
      O consentimento é registrado no momento do envio. Os dados de contato são
      sensíveis e ficam restritos à escola responsável pela lista.
    </p>
  </section>

  <section class="bg-white border border-gray-200 rounded-card shadow-card p-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-3">Dados educacionais públicos</h2>
    <p class="text-gray-700 leading-relaxed">
      Os indicadores escolares, municipais e de redes exibidos na plataforma vêm
      de bases públicas oficiais (por exemplo, Censo Escolar e IDEB) e são
      apresentados de forma agregada.
    </p>
  </section>

  <section class="bg-white border border-gray-200 rounded-card shadow-card p-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-3">Contato</h2>
    <p class="text-gray-700 leading-relaxed">
      Para dúvidas sobre seus dados ou para solicitar a remoção, fale com a
      escola responsável pela lista em que você se inscreveu.
    </p>
  </section>
</article>
