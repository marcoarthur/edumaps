<script>
  import { onMount } from 'svelte';
  import SchoolScores from './SchoolScores.svelte';
  import { fetchSchoolScores } from '../service/school.js'; // ajuste o caminho conforme necessário

  export let escola = null;
  export let isOpen = false;

  let schoolData = null;
  let loading = false;
  let error = null;

  // Observa a abertura do modal ou mudança de escola para carregar os dados
  $: if (isOpen && escola && escola.codigo_inep) {
    loadScores();
  }

  async function loadScores() {
    loading = true;
    error = null;
    schoolData = null;

    try {
      const data = await fetchSchoolScores(escola.codigo_inep);
      schoolData = data;
    } catch (err) {
      error = err.message;
      console.error('Erro ao carregar scores:', err);
    } finally {
      loading = false;
    }
  }

  function handleClose() {
    isOpen = false;
    schoolData = null;
    error = null;
    // Disparar evento para o pai
    dispatch('close');
  }

  // Impede scroll do body quando modal aberto
  onMount(() => {
    if (typeof window !== 'undefined') {
      const originalOverflow = window.getComputedStyle(document.body).overflow;
      return () => {
        document.body.style.overflow = originalOverflow;
      };
    }
  });

  $: if (isOpen) {
    document.body.style.overflow = 'hidden';
  } else {
    document.body.style.overflow = '';
  }

  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();
</script>

{#if isOpen}
  <div class="modal-overlay" on:click={handleClose}>
    <div class="modal-container" on:click|stopPropagation>
      <div class="modal-header">
        <h2>Scores da Escola</h2>
        <button class="close-btn" on:click={handleClose}>✕</button>
      </div>
      <div class="modal-body">
        {#if loading}
          <div class="loading">Carregando scores...</div>
        {:else if error}
          <div class="error">
            <p>Erro ao carregar os scores: {error}</p>
            <button on:click={loadScores}>Tentar novamente</button>
          </div>
        {:else if schoolData}
          <SchoolScores schoolData={{...schoolData, ...escola}} averages={null} />
        {:else}
          <div class="empty">Nenhum dado disponível</div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    backdrop-filter: blur(3px);
    animation: fadeIn 0.2s ease-out;
  }
  .modal-container {
    background: white;
    border-radius: 1rem;
    width: 90%;
    max-width: 850px;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    animation: slideUp 0.3s ease-out;
  }
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
    background: linear-gradient(135deg, #1e3a8a, #1e40af);
    border-radius: 1rem 1rem 0 0;
    color: white;
  }
  .modal-header h2 {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
  }
  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: white;
    opacity: 0.8;
    transition: opacity 0.2s;
    line-height: 1;
    padding: 0;
  }
  .close-btn:hover {
    opacity: 1;
  }
  .modal-body {
    padding: 1.5rem;
  }
  .loading, .error, .empty {
    text-align: center;
    padding: 2rem;
    font-size: 1rem;
  }
  .error {
    color: #dc2626;
  }
  .error button {
    margin-top: 0.75rem;
    padding: 0.5rem 1rem;
    background-color: #3b82f6;
    color: white;
    border: none;
    border-radius: 0.5rem;
    cursor: pointer;
  }
  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }
  @keyframes slideUp {
    from { transform: translateY(30px); opacity: 0; }
    to { transform: translateY(0); opacity: 1; }
  }
</style>
