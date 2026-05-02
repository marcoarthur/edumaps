<script>
  import { createEventDispatcher } from 'svelte';
  import SearchInput from './SearchInput.svelte';
  import LoadingSpinner from './LoadingSpinner.svelte';

  export let value = '';
  export let placeholder = 'Buscar...';
  export let fetchSuggestions = async (query) => [];  // função que retorna array
  export let minChars = 3;
  export let delay = 300;
  export let renderSuggestion = (item) => item.label || item;
  export let getSuggestionValue = (item) => item.value || item;
  export let disabled = false;

  let suggestions = [];
  let loading = false;
  let showDropdown = false;
  let searchValue = value;
  
  const dispatch = createEventDispatcher();

  const handleSearch = async (query) => {
    if (query.length < minChars) {
      suggestions = [];
      showDropdown = false;
      return;
    }

    loading = true;
    try {
      suggestions = await fetchSuggestions(query);
      showDropdown = suggestions.length > 0;
    } catch (err) {
      console.error('Erro ao buscar sugestões:', err);
      suggestions = [];
    } finally {
      loading = false;
    }
  };

  const selectSuggestion = (item) => {
    const selectedValue = getSuggestionValue(item);
    searchValue = renderSuggestion(item);
    value = selectedValue;
    suggestions = [];
    showDropdown = false;
    dispatch('select', { original: item, value: selectedValue });
  };

  // Expor métodos
  export function clear() {
    searchValue = '';
    value = '';
    suggestions = [];
    showDropdown = false;
  }
</script>

<div class="autocomplete-container">
  <SearchInput
    bind:value={searchValue}
    {placeholder}
    {disabled}
    {loading}
    {delay}
    onSearch={handleSearch}
  />

  {#if showDropdown}
    <div class="suggestions-dropdown">
      {#each suggestions as suggestion}
        <div class="suggestion-item" on:click={() => selectSuggestion(suggestion)}>
          {@html renderSuggestion(suggestion)}
          {#if suggestion.subtitle}
            <div class="suggestion-subtitle">{suggestion.subtitle}</div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .autocomplete-container {
    position: relative;
    width: 100%;
    z-index: 10000;  /* Adicionar z-index no container */
  }

  .suggestions-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
    margin-top: 0.25rem;
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    z-index: 100;
    max-height: 400px;
    overflow-y: auto;
  }

  .suggestion-item {
    padding: 0.75rem 1rem;
    cursor: pointer;
    border-bottom: 1px solid #f3f4f6;
    transition: background 0.2s;
  }

  .suggestion-item:hover {
    background: #f3f4f6;
  }

  .suggestion-subtitle {
    font-size: 0.7rem;
    color: #6b7280;
    margin-top: 0.25rem;
  }
</style>
