<script>
  // src/features/network-compare/components/NetworkCompareTable.svelte
  import { DataTable } from "@/shared/ui";
  import { formatDecimal, formatInt } from "../utils/transformNetworkData.js";

  /** @type {Array<object>} */
  let { networks = [] } = $props();

  const columns = [
    { key: "rede", label: "Rede", sortable: true },
    {
      key: "total_escolas",
      label: "Escolas",
      sortable: true,
      render: (row) => formatInt(row.total_escolas),
    },
    {
      key: "total_matriculas",
      label: "Matrículas",
      sortable: true,
      render: (row) => formatInt(row.total_matriculas),
    },
    {
      key: "total_docentes",
      label: "Docentes",
      sortable: true,
      render: (row) => formatInt(row.total_docentes),
    },
    {
      key: "total_etapas",
      label: "Etapas",
      sortable: true,
      render: (row) => formatInt(row.total_etapas),
    },
    {
      key: "media_etapas",
      label: "Etapas/escola",
      sortable: true,
      render: (row) => formatDecimal(row.media_etapas),
    },
    {
      key: "alunos_por_docente",
      label: "Alunos/docente",
      sortable: true,
      render: (row) => formatDecimal(row.alunos_por_docente),
    },
    {
      key: "perc_docentes_superior",
      label: "% doc. superior",
      sortable: true,
      render: (row) => `${formatDecimal(row.perc_docentes_superior)}%`,
    },
  ];
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-5">
  <div class="overflow-x-auto">
    <DataTable
      columns={columns}
      data={networks}
      rowKey="codigo_rede"
      caption="Tabela comparativa das redes"
    />
  </div>
</section>