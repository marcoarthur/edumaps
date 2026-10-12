<!-- src/features/gestor/components/relatorios/SecaoAssociacoes.svelte -->
<script>
  // Seção de associações (#219, fase 2): leitura simplificada da regressão.
  // Cada item diz se o fator anda junto com um desfecho maior, menor ou sem
  // relação clara, com o selo de segurança (alta/média/baixa), o corte e o n.
  // A direção nunca depende só de cor: seta + texto (o ícone é decorativo).
  import { formatarValor } from "../../utils/relatorioFormatos.js";

  /** @type {{secao: {id: string, titulo?: string, itens?: Array<object>, nota?: string}}} */
  let { secao } = $props();

  const DIRECAO = {
    maior: { seta: "↑", texto: "Associado a resultado maior", classe: "text-emerald-700 bg-emerald-50 border-emerald-200" },
    menor: { seta: "↓", texto: "Associado a resultado menor", classe: "text-rose-700 bg-rose-50 border-rose-200" },
    sem_relacao_clara: { seta: "–", texto: "Sem relação clara", classe: "text-gray-700 bg-gray-50 border-gray-200" },
  };

  const SEGURANCA = {
    alta: { rotulo: "Segurança alta", explica: "é muito pouco provável que seja acaso", classe: "bg-blue-100 text-blue-800" },
    media: { rotulo: "Segurança média", explica: "é pouco provável que seja acaso", classe: "bg-sky-50 text-sky-800" },
    baixa: { rotulo: "Segurança baixa", explica: "pode ser acaso", classe: "bg-gray-100 text-gray-700" },
  };

  const direcao = (d) => DIRECAO[d] ?? DIRECAO.sem_relacao_clara;
  const seguranca = (s) => SEGURANCA[s] ?? SEGURANCA.baixa;
  const itens = $derived(secao.itens ?? []);
</script>

<section class="space-y-3" aria-labelledby="secao-{secao.id}" data-testid="secao-associacoes">
  <h2 id="secao-{secao.id}" class="text-lg font-semibold text-gray-900">
    {secao.titulo ?? "Associações"}
  </h2>
  {#if itens.length}
    <ul class="grid gap-3 sm:grid-cols-2">
      {#each itens as item, i (i)}
        {@const d = direcao(item.direcao)}
        {@const s = seguranca(item.seguranca)}
        <li
          class="bg-white border border-gray-200 rounded-card shadow-card p-4 space-y-2 print:shadow-none print:break-inside-avoid"
          data-testid="associacao"
          data-direcao={item.direcao}
          data-seguranca={item.seguranca}
        >
          <p class="font-semibold text-gray-900">
            {item.rotulo}{#if item.corte}{" "}<span class="font-normal text-gray-500">· {item.corte}</span>{/if}
          </p>
          <p
            class="inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-sm font-medium {d.classe}"
            data-testid="associacao-direcao"
          >
            <span aria-hidden="true" class="text-base leading-none">{d.seta}</span>
            <span>{d.texto}</span>
          </p>
          <p class="text-xs text-gray-600" data-testid="associacao-seguranca">
            <span class="inline-block rounded-full px-2 py-0.5 font-medium {s.classe}">{s.rotulo}</span>{" "}
            <span>— {s.explica}.</span>
          </p>
          {#if item.n !== undefined && item.n !== null}
            <p class="text-xs text-gray-500" data-testid="associacao-n">
              {formatarValor(item.n, "inteiro")} escolas analisadas
            </p>
          {/if}
        </li>
      {/each}
    </ul>
  {:else}
    <p class="text-sm text-gray-500">Sem associações para este recorte.</p>
  {/if}
  {#if secao.nota}
    <p class="text-sm text-gray-600 italic" data-testid="associacoes-nota">{secao.nota}</p>
  {/if}
</section>
