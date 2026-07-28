<script>
  import { DataTable } from '@/shared/ui';

  /**
   * @typedef {Object} PayrollRecord
   * @property {number} ano
   * @property {number} carga_horaria
   * @property {string} categoria
   * @property {number} cod_inep
   * @property {string} cod_municipio
   * @property {string} cpf
   * @property {string} escola
   * @property {string} mes
   * @property {string} nome_profissional
   * @property {string} rede
   * @property {string} salario_base
   * @property {string} salario_fundeb_max
   * @property {string} salario_fundeb_min
   * @property {string} salario_outros
   * @property {string} salario_total
   * @property {string} segmento_ensino
   * @property {string} situacao
   * @property {string} tipo
   */

  // Única chamada a $props() com todas as propriedades
  let {
    /** @type {PayrollRecord[]} */
    payrollData = [],
    /** @type {string} */
    caption = 'Folha de Pagamento – Profissionais da Educação',
    /** @type {string} */
    footer = '',
  } = $props();

  // Formata valores monetários (string -> número com 2 casas)
  function formatCurrency(value) {
    if (!value) return '—';
    const num = parseFloat(value);
    if (isNaN(num)) return value;
    return num.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  }

  // Definição das colunas – selecionamos os campos mais relevantes
  const columns = [
    {
      key: 'nome_profissional',
      label: 'Profissional',
      sortable: true,
    },
    {
      key: 'categoria',
      label: 'Categoria',
      sortable: true,
    },
    {
      key: 'carga_horaria',
      label: 'Carga Horária',
      sortable: true,
      render: (row) => `${row.carga_horaria}h`,
    },
    {
      key: 'situacao',
      label: 'Situação',
      sortable: true,
    },
    {
      key: 'salario_base',
      label: 'Salário Base',
      sortable: true,
      render: (row) => formatCurrency(row.salario_base),
    },
    {
      key: 'salario_total',
      label: 'Salário Total',
      sortable: true,
      render: (row) => formatCurrency(row.salario_total),
    },
    {
      key: 'mes',
      label: 'Mês',
      sortable: true,
    },
    {
      key: 'ano',
      label: 'Ano',
      sortable: true,
    },
  ];
</script>

<DataTable
  columns={columns}
  data={payrollData}
  {caption}
  {footer}
  rowKey="cpf"
/>
