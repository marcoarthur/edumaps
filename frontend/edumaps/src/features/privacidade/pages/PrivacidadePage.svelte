<!-- src/features/privacidade/pages/PrivacidadePage.svelte -->
<script>
  // Página pública de política de privacidade (rota /privacidade). Dá base
  // informada ao consentimento da autoinscrição por QR (issue #208).
  // Issue #214: mostra o texto de consentimento vigente (versão e data), os
  // prazos de retenção configurados e como excluir os dados. Se a API falhar,
  // fica o texto estático mínimo (sem texto vigente nem prazos).
  import { onMount } from "svelte";
  import { consentimentoVigente } from "@/features/inscricao/api/canaisPublicApi.js";
  import TextoMarkdown from "@/features/inscricao/components/TextoMarkdown.svelte";

  const resumo = [
    "Nome e contatos são usados apenas para a escola falar com você.",
    "Os dados ficam restritos à escola e não são compartilhados com terceiros.",
    "Você pode pedir a remoção dos seus dados a qualquer momento.",
  ];

  let consentimento = $state(null);
  let carregando = $state(true);

  const ativo = (v) => v === true || v === 1 || v === "1" || v === "true";
  const plural = (n, um, varios) => `${n} ${Number(n) === 1 ? um : varios}`;

  // prazos em linguagem simples (só os definidos)
  const prazos = $derived.by(() => {
    const r = consentimento?.retencao;
    if (!r || !ativo(r.enabled)) return [];
    const out = [];
    if (r.metadados_dias != null) {
      out.push(
        `Dados técnicos da inscrição (endereço de internet anonimizado e navegador usado) são apagados após ${plural(r.metadados_dias, "dia", "dias")}.`,
      );
    }
    if (r.pendentes_dias != null) {
      out.push(
        `Em listas que pedem confirmação do contato, inscrições nunca confirmadas são removidas após ${plural(r.pendentes_dias, "dia", "dias")}.`,
      );
    }
    if (r.listas_inativas_meses != null) {
      out.push(
        `Quando a escola desativa uma lista, os inscritos são removidos após ${plural(r.listas_inativas_meses, "mês", "meses")} — a menos que estejam em outra lista ativa da escola.`,
      );
    }
    return out;
  });

  const publicadaEm = $derived(
    consentimento?.publicada_em
      ? new Date(consentimento.publicada_em).toLocaleDateString("pt-BR")
      : null,
  );

  onMount(() => {
    consentimentoVigente()
      .then((c) => {
        consentimento = c?.texto ? c : null;
      })
      .catch(() => {
        consentimento = null; // fallback estático
      })
      .finally(() => {
        carregando = false;
      });
  });
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
      <strong>nome</strong> e os contatos que a lista pede (<strong>telefone</strong>
      e/ou <strong>e-mail</strong>). Esses dados são gravados para que a escola
      possa entrar em contato com você.
    </p>
    <ul class="mt-4 space-y-2">
      {#each resumo as item}
        <li class="flex gap-2 text-gray-700">
          <span class="text-brand-600 font-bold">→</span>
          <span>{item}</span>
        </li>
      {/each}
    </ul>
    <p class="mt-4 text-sm text-gray-500">
      O consentimento é registrado no momento do envio, junto com a versão do
      texto aceito. Os dados de contato ficam restritos à escola responsável pela lista.
    </p>
  </section>

  {#if consentimento}
    <section
      class="bg-white border border-gray-200 rounded-card shadow-card p-6"
      data-testid="privacidade-consentimento"
    >
      <h2 class="text-lg font-semibold text-gray-900">Termo de consentimento vigente</h2>
      <p class="text-xs text-gray-500 mt-1 mb-3" data-testid="privacidade-versao">
        Versão {consentimento.versao}{#if publicadaEm} · publicada em {publicadaEm}{/if}
      </p>
      <div class="space-y-2 text-sm text-gray-700">
        <TextoMarkdown texto={consentimento.texto} />
      </div>
    </section>
  {:else if carregando}
    <p class="text-sm text-gray-400">Carregando o termo de consentimento vigente…</p>
  {/if}

  {#if prazos.length > 0}
    <section
      class="bg-white border border-gray-200 rounded-card shadow-card p-6"
      data-testid="privacidade-retencao"
    >
      <h2 class="text-lg font-semibold text-gray-900 mb-3">Por quanto tempo guardamos</h2>
      <ul class="space-y-2">
        {#each prazos as item}
          <li class="flex gap-2 text-gray-700">
            <span class="text-brand-600 font-bold">→</span>
            <span>{item}</span>
          </li>
        {/each}
      </ul>
      <p class="mt-3 text-sm text-gray-500">
        A limpeza é automática e diária. Ao remover, ficam apenas registros sem dados pessoais.
      </p>
    </section>
  {/if}

  <section
    class="bg-white border border-gray-200 rounded-card shadow-card p-6"
    data-testid="privacidade-como-excluir"
  >
    <h2 class="text-lg font-semibold text-gray-900 mb-3">Como excluir seus dados</h2>
    <ul class="space-y-2 text-gray-700 leading-relaxed">
      <li>
        <strong>Pelo seu link pessoal:</strong> ao se inscrever, você recebe o link
        “Remover meus dados”. Abra-o e confirme — seu nome, telefone e e-mail são
        apagados de todas as listas daquela escola.
      </li>
      <li>
        <strong>Pela escola:</strong> se não tiver mais o link, peça a remoção à escola
        responsável pela lista; a gestão da escola pode remover sua inscrição.
      </li>
    </ul>
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
      Para dúvidas sobre seus dados, fale com a escola responsável pela lista em
      que você se inscreveu.
    </p>
  </section>
</article>
