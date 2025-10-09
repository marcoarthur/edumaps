<script>
  import { onDestroy } from 'svelte';
  
  let jobId = null;
  let progress = 0;
  let jobStatus = 'idle';
  let finalResult = null;
  let errorMessage = '';
  let eventSource = null;

  async function startQuery() {
    jobStatus = 'loading';
    errorMessage = '';
    finalResult = null;
    progress = 0;

    try {
      // Start the job
      const response = await fetch('/api/query-osm?fid=example_fid');
      const data = await response.json();
      jobId = data.job_id;
      jobStatus = 'active';
      
      // Connect to SSE stream
      setupEventSource();
    } catch (error) {
      jobStatus = 'error';
      errorMessage = 'Failed to start the job';
    }
  }

  function setupEventSource() {
    if (eventSource) {
      eventSource.close();
    }

    eventSource = new EventSource(`/api/job-events/${jobId}`);
    
    eventSource.onopen = () => {
      console.log('SSE connection opened');
    };

    eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        progress = data.progress || 0;
        jobStatus = data.status;
        
        if (data.result) {
          finalResult = data.result;
        }
        
        if (data.status === 'finished' || data.status === 'failed') {
          eventSource.close();
          if (data.status === 'failed') {
            errorMessage = 'Job processing failed';
          }
        }
      } catch (error) {
        console.error('Error parsing SSE data:', error);
      }
    };

    eventSource.onerror = (error) => {
      console.error('SSE error:', error);
      jobStatus = 'error';
      errorMessage = 'Connection error';
      eventSource.close();
    };
  }

  function cancelJob() {
    if (eventSource) {
      eventSource.close();
      eventSource = null;
    }
    jobStatus = 'idle';
    progress = 0;
  }

  onDestroy(() => {
    if (eventSource) {
      eventSource.close();
    }
  });
</script>

<div class="w-full max-w-md mx-auto p-4">
  {#if jobStatus === 'idle'}
    <button on:click={startQuery} class="btn btn-primary">
      Start OSM Query
    </button>
  
  {:else if jobStatus === 'loading'}
    <div class="flex items-center gap-2">
      <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-gray-900"></div>
      <p>Starting job...</p>
    </div>
  
  {:else if jobStatus === 'active'}
    <div>
      <div class="flex justify-between mb-1">
        <span class="font-medium">Processing OSM Data</span>
        <span>{progress}%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div 
          class="bg-blue-600 h-2 rounded-full transition-all duration-300" 
          style="width: {progress}%"
        ></div>
      </div>
      <button on:click={cancelJob} class="mt-2 text-sm text-gray-600 hover:text-gray-800">
        Cancel
      </button>
    </div>
  
  {:else if jobStatus === 'finished'}
    <div class="p-4 bg-green-50 border border-green-200 rounded-lg">
      <div class="flex items-center gap-2 text-green-800 mb-2">
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        <span class="font-medium">Job Complete!</span>
      </div>
      {#if finalResult}
        <p class="text-green-700">Result: {finalResult}</p>
      {/if}
      <button on:click={() => jobStatus = 'idle'} class="mt-3 btn btn-outline">
        Start New Query
      </button>
    </div>
  
  {:else if jobStatus === 'error'}
    <div class="p-4 bg-red-50 border border-red-200 rounded-lg">
      <div class="flex items-center gap-2 text-red-800 mb-2">
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
        </svg>
        <span class="font-medium">Error</span>
      </div>
      <p class="text-red-700">{errorMessage}</p>
      <button on:click={() => jobStatus = 'idle'} class="mt-3 btn btn-outline">
        Try Again
      </button>
    </div>
  {/if}
</div>

<style>
  .btn {
    @apply px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors;
  }
  .btn-outline {
    @apply bg-transparent border border-current text-current hover:bg-gray-100;
  }
  .btn-primary {
    @apply bg-blue-600 hover:bg-blue-700;
  }
</style>
