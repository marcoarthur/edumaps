<script>
  import { createEventDispatcher } from 'svelte';
  
  export let loading = false;
  
  const dispatch = createEventDispatcher();
  
  let nomeEscola = '';
  let cidade = '';

  function buscarEscolas() {
    if (!nomeEscola.trim() && !cidade.trim()) {
      dispatch('error', { message: 'Informe pelo menos o nome da escola ou a cidade' });
      return;
    }
    
    dispatch('search', { nome: nomeEscola, cidade });
  }

  function limparFiltros() {
    nomeEscola = '';
    cidade = '';
    dispatch('clear');
  }
</script>

<div class="search-form">
  <form on:submit|preventDefault={buscarEscolas} class="form-container">
    <div class="form-grid">
      <div class="form-field">
        <label for="nome-escola">
          🏫 Nome da Escola
        </label>
        <input
          id="nome-escola"
          type="text"
          bind:value={nomeEscola}
          placeholder="Digite o nome da escola..."
          disabled={loading}
        />
        <small>Exemplo: "Maria", "São José", "Profª Helena"</small>
      </div>

      <div class="form-field">
        <label for="cidade">
          🌆 Cidade
        </label>
        <input
          id="cidade"
          type="text"
          bind:value={cidade}
          placeholder="Digite o nome da cidade..."
          disabled={loading}
        />
        <small>Exemplo: "Ubatuba", "São Paulo", "Campinas"</small>
      </div>
    </div>

    <div class="form-actions">
      <button
        type="submit"
        disabled={loading || (!nomeEscola.trim() && !cidade.trim())}
        class="btn-primary"
      >
        {#if loading}
          <span class="spinner"></span>
          Buscando...
        {:else}
          🔍 Buscar Escolas
        {/if}
      </button>

      <button
        type="button"
        on:click={limparFiltros}
        disabled={loading}
        class="btn-secondary"
      >
        Limpar
      </button>
    </div>

    <div class="form-hint">
      💡 Dica: Você pode buscar por nome da escola, por cidade, ou combinar ambos para resultados mais precisos.
    </div>
  </form>
</div>

<style>
  .search-form {
    background: white;
    border-radius: 0.5rem;
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
    padding: 1.5rem;
  }

  .form-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
    margin-bottom: 1.5rem;
  }

  .form-field {
    display: flex;
    flex-direction: column;
  }

  .form-field label {
    font-size: 0.875rem;
    font-weight: 500;
    color: #374151;
    margin-bottom: 0.5rem;
  }

  .form-field input {
    padding: 0.5rem 0.75rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    transition: all 0.2s;
  }

  .form-field input:focus {
    outline: none;
    border-color: #3b82f6;
    ring: 2px solid #3b82f6;
  }

  .form-field input:disabled {
    background-color: #f3f4f6;
    cursor: not-allowed;
  }

  .form-field small {
    margin-top: 0.25rem;
    font-size: 0.75rem;
    color: #6b7280;
  }

  .form-actions {
    display: flex;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .btn-primary {
    flex: 1;
    background-color: #2563eb;
    color: white;
    font-weight: 500;
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }

  .btn-primary:hover:not(:disabled) {
    background-color: #1d4ed8;
  }

  .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-secondary {
    padding: 0.5rem 1rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    color: #374151;
    background: white;
    transition: all 0.2s;
  }

  .btn-secondary:hover:not(:disabled) {
    background-color: #f3f4f6;
  }

  .btn-secondary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .spinner {
    display: inline-block;
    width: 1rem;
    height: 1rem;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-radius: 50%;
    border-top-color: white;
    animation: spin 0.6s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .form-hint {
    font-size: 0.75rem;
    color: #6b7280;
    background-color: #f9fafb;
    padding: 0.75rem;
    border-radius: 0.375rem;
  }

  @media (max-width: 768px) {
    .form-grid {
      grid-template-columns: 1fr;
      gap: 1rem;
    }
  }
</style>
