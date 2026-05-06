<script>
  import LoadingSpinner from './LoadingSpinner.svelte';

  export let value = '';
  export let placeholder = 'Buscar...';
  export let disabled = false;
  export let loading = false;
  export let delay = 0;  // ms de debounce
  export let onSearch = (value) => {};

  let debounceTimer;
  let internalValue = value;

  $: internalValue = value;

  const handleInput = (e) => {
    internalValue = e.target.value;
    
    if (delay > 0) {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        onSearch(internalValue);
      }, delay);
    } else {
      onSearch(internalValue);
    }
  };
</script>

<div class="search-input-container">
  <span class="search-icon">🔍</span>
  <input
    type="text"
    bind:value={internalValue}
    on:input={handleInput}
    {placeholder}
    {disabled}
    class="search-input"
  />
  {#if loading}
    <div class="spinner-wrapper">
      <LoadingSpinner size="16px" />
    </div>
  {/if}
</div>

<style>
  .search-input-container {
    position: relative;
    display: flex;
    align-items: center;
    width: 100%;
  }

  .search-icon {
    position: absolute;
    left: 12px;
    font-size: 1rem;
    color: #9ca3af;
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    padding: 0.75rem 1rem 0.75rem 2.5rem;
    font-size: 1rem;
    border: 2px solid #e5e7eb;
    border-radius: 0.5rem;
    transition: all 0.2s;
  }

  .search-input:focus {
    outline: none;
    border-color: #2563eb;
    box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
  }

  .search-input:disabled {
    background-color: #f3f4f6;
    cursor: not-allowed;
  }

  .spinner-wrapper {
    position: absolute;
    right: 12px;
  }
</style>
