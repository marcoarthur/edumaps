<script>
  export let progress = null;
  
  // Calculate progress percentage safely
  $: percentage = progress?.progress?.total > 0 
    ? Math.round((progress.progress.processed / progress.progress.total) * 100)
    : 0;
  
  // Determine if we're in progress
  $: isActive = progress?.progress?.state === 'active';
  $: isFinished = progress?.progress?.state === 'finished';
  $: isUnknown = progress?.progress?.state === 'unknown';
  
  // Get current phase
  $: currentPhase = progress?.progress?.phase || 'waiting';
</script>

<div class="progress-panel">
  {#if progress}
    <div class="progress-info">
      <div class="phase">Phase: <strong>{currentPhase}</strong></div>
      <div class="status">Status: <strong>{progress.progress.state}</strong></div>
      
      {#if isActive || isUnknown}
        <div class="progress-details">
          <span class="count">
            {progress.progress.processed} / {progress.progress.total}
          </span>
          {#if percentage > 0}
            <span class="percentage">({percentage}%)</span>
          {/if}
        </div>
      {/if}
    </div>

    {#if isActive && progress.progress.total > 0}
      <div class="progress-bar-container">
        <div 
          class="progress-bar" 
          style="width: {percentage}%"
          role="progressbar"
          aria-valuenow={percentage}
          aria-valuemin="0"
          aria-valuemax="100"
        >
          <span class="progress-text">{percentage}%</span>
        </div>
      </div>
    {:else if isUnknown}
      <div class="progress-bar-container">
        <div class="progress-bar indeterminate" role="progressbar">
          <span class="progress-text">Initializing...</span>
        </div>
      </div>
    {:else if isFinished}
      <div class="completion-message">
        ✅ Operation completed successfully!
      </div>
    {/if}
  {:else}
    <div class="waiting-message">
      Waiting for operation to start...
    </div>
  {/if}
</div>

<style>
  .progress-panel {
    border: 1px solid #e0e0e0;
    border-radius: 8px;
    padding: 1rem;
    background: #f9f9f9;
    max-width: 400px;
    margin: 1rem 0;
  }

  .progress-info {
    margin-bottom: 0.75rem;
  }

  .phase, .status {
    margin-bottom: 0.25rem;
    font-size: 0.9rem;
  }

  .progress-details {
    margin-top: 0.5rem;
    font-size: 0.85rem;
    color: #666;
  }

  .count, .percentage {
    margin-right: 0.5rem;
  }

  .progress-bar-container {
    width: 100%;
    height: 24px;
    background: #e0e0e0;
    border-radius: 12px;
    overflow: hidden;
    position: relative;
  }

  .progress-bar {
    height: 100%;
    background: linear-gradient(90deg, #4CAF50, #45a049);
    border-radius: 12px;
    transition: width 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 40px; /* Ensure text is visible even at low percentages */
  }

  .progress-bar.indeterminate {
    background: linear-gradient(90deg, #2196F3, #21b0f3);
    animation: indeterminate 1.5s infinite linear;
    width: 60% !important; /* Override the style attribute */
  }

  .progress-text {
    color: white;
    font-size: 0.75rem;
    font-weight: bold;
    text-shadow: 1px 1px 1px rgba(0,0,0,0.3);
  }

  .completion-message {
    color: #2E7D32;
    font-weight: bold;
    text-align: center;
    padding: 0.5rem;
    background: #E8F5E9;
    border-radius: 4px;
  }

  .waiting-message {
    color: #666;
    font-style: italic;
    text-align: center;
    padding: 0.5rem;
  }

  @keyframes indeterminate {
    0% {
      transform: translateX(-100%);
    }
    100% {
      transform: translateX(200%);
    }
  }
</style>
