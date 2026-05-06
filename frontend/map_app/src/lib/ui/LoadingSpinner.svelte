<script>
  export let size = '20px';
  export let color = '#2563eb';
</script>

<div class="spinner" style="width: {size}; height: {size}; border-top-color: {color};"></div>

<style>
  .spinner {
    border: 2px solid #e5e7eb;
    border-top-color: #2563eb;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>
