<script>
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();

  export let cityName = '';
  export let statusMessage = '';

  function handleKeyPress(e) {
    if (e.key === 'Enter') dispatch('search');
  }
</script>

<div class="controls">
  <button on:click={() => dispatch('search')}>Search City</button>
  <button on:click={() => dispatch('clear')}>Clear Map</button>
  <input
    bind:value={cityName}
    on:keypress={handleKeyPress}
    type="text"
    placeholder="Enter city name"
    class="form-control"
  />
  <span id="status">{statusMessage}</span>
</div>

<style>
  .controls {
    margin-bottom: 15px;
    padding: 14px;
    background: #f5f5f5;
    border-radius: 5px;
  }
  .form-control {
    display: inline-block;
    width: 200px;
    padding: 6px 12px;
    font-size: 14px;
    border: 1px solid #ccc;
    border-radius: 4px;
  }
</style>
