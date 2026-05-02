<script>
  export let value = '';
  export let placeholder = 'Buscar...';
  export let disabled = false;
  export let onSearch = (value) => {};
</script>

<div class="search-simple">
  <input
    type="text"
    bind:value
    on:input={() => onSearch(value)}
    {placeholder}
    {disabled}
    class="simple-input"
  />
  <span class="simple-icon">🔍</span>
</div>

<style>
  .search-simple {
    position: relative;
    width: 100%;
  }

  .simple-input {
    width: 100%;
    padding: 0.5rem 1rem 0.5rem 2rem;
    font-size: 0.875rem;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
  }

  .simple-input:focus {
    outline: none;
    border-color: #2563eb;
  }

  .simple-icon {
    position: absolute;
    left: 8px;
    top: 50%;
    transform: translateY(-50%);
    font-size: 0.875rem;
    color: #9ca3af;
  }
</style>
