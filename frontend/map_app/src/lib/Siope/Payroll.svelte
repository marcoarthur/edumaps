<script>
  import { formatValue } from '../js/siope.js';
  
  // O array de dados do payroll do SIOPE (e.g., RemuneracaoMunicipal)
  export let payrollData = [];

  // Mapeamento de rótulos específicos para o payroll
  const payrollLabels = {
      'tipo': 'Tipo',
      'ano': 'Ano de Referência',
      'mes': 'Mês',
      'nome_profissional': 'Nome do Profissional',
      'cod_municipio': 'Código IBGE do município',
      'cod_inep': 'Código INEP da escola',
      'escola': 'Nome da Escola',
      'carga_horaria': 'Carga Horária Semanal',
      'cpf': 'CPF do profissional',
      'situacao': 'Situação / Tipo contrato',
      'segmento_ensino': 'Segmento de ensino em que atua',
      'rede': 'Rede da escola',
      'salario_base': 'Salário Base',
      'salario_fundeb_max': 'Salário com até 70% parcela FUNDEB',
      'salario_fundeb_min': 'Salário com até 30% parcela FUNDEB',
      'salario_outros': 'Outras fontes',
      'salario_total': 'Total salário'
  };

  function formatPayrollValue(key, value) {
      if (key === 'salario_total' || key === 'total_salarios') {
          return Number(value).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
      }
      return formatValue(key, value); // Reutiliza a função de formatação geral
  }
</script>

<div class="siope-data-container">
  <h4>💸 Detalhes do Payroll SIOPE ({payrollData.length} registros)</h4>
  
  {#if payrollData.length > 0}
    <table class="payroll-details">
        <thead>
            <tr>
                {#each Object.keys(payrollData[0] || {}) as key}
                    <th>{payrollLabels[key] || key.toUpperCase()}</th>
                {/each}
            </tr>
        </thead>
        <tbody>
            {#each payrollData.slice(0, 10) as item} <tr>
                    {#each Object.entries(item) as [key, value]}
                        <td>{formatPayrollValue(key, value)}</td>
                    {/each}
                </tr>
            {/each}
        </tbody>
    </table>
    {#if payrollData.length > 10}
        <p class="note">... e mais {payrollData.length - 10} registros. (Total: {payrollData.length})</p>
    {/if}
  {:else}
    <p>Nenhum registro de folha de pagamento do SIOPE encontrado para este ano.</p>
  {/if}
</div>

<style>
  .siope-data-container {
      margin-top: 1.5rem;
      padding-top: 1rem;
      border-top: 1px solid #ddd;
  }
  .payroll-details {
      width: 100%;
      border-collapse: collapse;
  }
  .payroll-details th, .payroll-details td {
      border: 1px solid #eee;
      padding: 8px;
      text-align: left;
      font-size: 0.85rem;
  }
  .payroll-details th {
      background-color: #f1f1f1;
  }
  .note {
      font-size: 0.8rem;
      color: #6c757d;
      margin-top: 0.5rem;
  }
</style>
