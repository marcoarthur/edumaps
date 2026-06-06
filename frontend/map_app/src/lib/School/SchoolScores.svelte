<script>
  export let schoolData;
  export let averages = null;

  const scoreKeys = [
    { key: 'score_capacidade_atendimento', label: 'Capacidade de Atendimento' },
    { key: 'score_infraestrutura', label: 'Infraestrutura' },
    { key: 'score_capacitacao_docente', label: 'Capacitação Docente' },
    { key: 'score_diversidade_discente', label: 'Diversidade Discente' },
    { key: 'score_capacidade_gestora', label: 'Capacidade Gestora' },
    { key: 'score_sustentabilidade', label: 'Sustentabilidade' }
  ];

  function formatScore(value) {
    const num = parseFloat(value);
    return isNaN(num) ? '—' : num.toFixed(1);
  }

  function getBarColor(score) {
    const num = parseFloat(score);
    if (isNaN(num)) return '#d1d5db'; // cinza claro
    if (num < 3) return '#ef4444';    // vermelho
    if (num < 6) return '#eab308';    // amarelo
    if (num < 8) return '#3b82f6';    // azul
    return '#22c55e';                 // verde
  }
</script>

<div class="score-card">
  <div class="score-header">
    <h2>{schoolData.escola}</h2>
    <p class="address">Endereço: {schoolData.endereco}</p>
    <p>Código: {schoolData.co_entidade} | Ano: {schoolData.nu_ano_censo}</p>
    <p class="update-date">Atualizado em: {new Date(schoolData.data_atualizacao).toLocaleString()}</p>
  </div>

  <div class="score-list">
    {#each scoreKeys as item (item.key)}
      {@const scoreValue = schoolData[item.key]}
      {@const scoreNum = parseFloat(scoreValue)}
      {@const hasAverage = averages && averages[item.key]}
      <div class="score-item">
        <div class="score-row">
          <div class="score-label">{item.label}</div>
          <div class="score-number">{formatScore(scoreValue)} / 10</div>
        </div>
        <div class="bar-bg">
          <div
            class="bar-fill"
            style="width: {Math.min(100, Math.max(0, scoreNum * 10))}%; background-color: {getBarColor(scoreValue)};"
          ></div>
        </div>
        {#if hasAverage}
          <div class="averages">
            {#if averages[item.key].municipal !== undefined}
              <span>Municipal: {averages[item.key].municipal.toFixed(1)}</span>
            {/if}
            {#if averages[item.key].estadual !== undefined}
              <span>Estadual: {averages[item.key].estadual.toFixed(1)}</span>
            {/if}
            {#if averages[item.key].nacional !== undefined}
              <span>Nacional: {averages[item.key].nacional.toFixed(1)}</span>
            {/if}
          </div>
        {/if}
      </div>
    {/each}
  </div>
</div>

<style>
  .score-card {
    max-width: 700px;
    margin: 2rem auto;
    background: white;
    border-radius: 0.75rem;
    box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.02);
    border: 1px solid #e5e7eb;
    overflow: hidden;
    font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
  }
  .score-header {
    background: linear-gradient(135deg, #1e3a8a, #1e40af);
    padding: 1.25rem 1.5rem;
    color: white;
  }
  .score-header h2 {
    font-size: 1.25rem;
    font-weight: 700;
    margin: 0 0 0.25rem 0;
  }
  .score-header p {
    margin: 0.25rem 0;
    font-size: 0.875rem;
    opacity: 0.9;
  }
  .update-date {
    font-size: 0.75rem;
    opacity: 0.75;
  }
  .address {
    font-size: 0.80rem;
    opacity: 0.50;
  }
  .score-list {
    padding: 0;
  }
  .score-item {
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }
  .score-item:last-child {
    border-bottom: none;
  }
  .score-row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    flex-wrap: wrap;
    margin-bottom: 0.5rem;
  }
  .score-label {
    font-weight: 600;
    color: #1f2937;
  }
  .score-number {
    font-weight: 700;
    font-size: 1.125rem;
    color: #111827;
  }
  .bar-bg {
    background-color: #e5e7eb;
    border-radius: 9999px;
    height: 0.75rem;
    overflow: hidden;
  }
  .bar-fill {
    height: 0.75rem;
    border-radius: 9999px;
    transition: width 0.3s ease;
  }
  .averages {
    margin-top: 0.75rem;
    padding-top: 0.5rem;
    border-top: 1px solid #f3f4f6;
    font-size: 0.7rem;
    color: #6b7280;
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
  }
  .averages span {
    background: #f9fafb;
    padding: 0.25rem 0.5rem;
    border-radius: 0.25rem;
  }
</style>
