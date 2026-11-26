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
   * @property {number|null} [base_40h_ano]  #598: base por 40 h no ano (mês típico, rede inteira)
   * @property {boolean|null} [abaixo_piso_ano]  #598: abaixo do piso no ano, pela regra da contagem
   */

  // Única chamada a $props() com todas as propriedades
  let {
    /** @type {PayrollRecord[]} */
    payrollData = [],
    /** @type {string} */
    caption = 'Folha de Pagamento – Profissionais da Educação',
    /** @type {string} */
    footer = '',
    /** #598: mostra a coluna da base por 40 h no ano e a marca do piso */
    mostrarPiso = false,
    /** #602: ordenação da lista inteira por quem pagina (repassado ao DataTable) */
    onsort = undefined,
  } = $props();

  // Formata valores monetários (string -> número com 2 casas)
  function formatCurrency(value) {
    if (!value) return '—';
    const num = parseFloat(value);
    if (isNaN(num)) return value;
    return num.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  }

  // Definição das colunas – selecionamos os campos mais relevantes
  // #598 (QB-02 da P2): a base por 40 h da pessoa no ano e a marca do piso
  const colunaPiso = {
    key: 'base_40h_ano',
    label: 'Base por 40 h no ano',
    sortable: true,
    render: (row) => row.base_40h_ano == null
      ? '—'
      : `${formatCurrency(row.base_40h_ano)}${row.abaixo_piso_ano ? ' · abaixo do piso' : ''}`,
  };

  const base = [
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
    'PISO',
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
  const columns = $derived(base.flatMap((c) => (c === 'PISO' ? (mostrarPiso ? [colunaPiso] : []) : [c])));
</script>

<!-- Sem rowKey: a folha não tem identificador de linha. O CPF vem mascarado
     (xxx.730.981-xx) e a mesma pessoa pode ter mais de um pagamento no mês
     (medido: INEP 51036851, 02/2026), então o DataTable usa a posição. -->
<DataTable
  columns={columns}
  data={payrollData}
  {onsort}
  {caption}
  {footer}
/>
