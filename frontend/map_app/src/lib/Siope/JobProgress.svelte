<script>
    import { onMount, onDestroy } from 'svelte';
    import { monitorJobProgress } from '../js/siope.js';

    export let jobId;
    export let jobName = "Processamento SIOPE";
    export let onJobComplete; // Callback para quando o job terminar (passa os dados)

    let progressPercentage = 0;
    let jobStatus = 'Iniciando...';
    let errorMessage = null;

    let cleanup = () => {}; // Função para fechar a conexão SSE

    onMount(() => {
        // Assume que a URL de progresso é /api/job/progress/:id
        const progressUrl = `/api/job/progress/${jobId}`;

        console.log(`JobProgress: Monitorando Job ID ${jobId} via SSE em ${progressUrl}`);
        
        // monitorJobProgress retorna uma função de limpeza (cleanup)
        cleanup = monitorJobProgress(
            progressUrl,
            (data) => {
              console.log(data);
                // Função de atualização (do SSE onmessage)
                jobStatus = data.progress.state;
                if (data.progress.total && data.progress.total > 0) {
                    progressPercentage = (data.progress.processed / data.progress.total)*100.0;
                }
                
                if (data.progress.state === 'finished' && data.result) {
                    cleanup(); // Fecha a conexão
                    // Chama o callback para o componente pai renderizar os dados
                    onJobComplete(data.result);
                }
                
                if (data.progress.state === 'failed') {
                    errorMessage = data.error || 'Erro desconhecido durante o processamento.';
                    cleanup();
                }
            },
            (error) => {
                // Função de erro
                jobStatus = 'Erro de Conexão';
                errorMessage = error.message;
                cleanup();
            }
        );
    });

    onDestroy(() => {
        cleanup(); // Garante que a conexão SSE seja fechada ao destruir o componente
    });
</script>

<div class="progress-card">
    <h5 class="progress-title">⏳ {jobName} em Processamento...</h5>

    {#if errorMessage}
        <div class="error-message">❌ {jobStatus}: {errorMessage}</div>
    {:else}
        <div class="progress-status">{jobStatus} ({Math.round(progressPercentage)}%)</div>
        <div class="progress-bar-container">
            <div 
                class="progress-bar" 
                style="width: {progressPercentage}%"
                aria-valuenow={progressPercentage}
                aria-valuemin="0"
                aria-valuemax="100"
            ></div>
        </div>
        <p class="job-note">ID do Job: {jobId}. Os dados serão carregados automaticamente ao finalizar.</p>
    {/if}
</div>

<style>
    .progress-card {
        background-color: #fff3cd; /* Cor de aviso */
        border: 1px solid #ffeeba;
        padding: 1rem;
        border-radius: 8px;
        margin-top: 1rem;
    }
    .progress-title {
        color: #856404;
        margin-top: 0;
        margin-bottom: 0.5rem;
        font-size: 1rem;
        font-weight: 600;
    }
    .progress-status {
        font-size: 0.9rem;
        color: #383d41;
        margin-bottom: 0.5rem;
    }
    .progress-bar-container {
        height: 10px;
        background-color: #e9ecef;
        border-radius: 5px;
        overflow: hidden;
        margin-bottom: 0.5rem;
    }
    .progress-bar {
        height: 100%;
        background-color: #007bff; /* Cor azul primária */
        transition: width 0.4s ease;
    }
    .job-note {
        font-size: 0.75rem;
        color: #6c757d;
        margin-bottom: 0;
    }
    .error-message {
        color: #721c24;
        background-color: #f8d7da;
        border: 1px solid #f5c6cb;
        padding: 0.5rem;
        border-radius: 4px;
    }
</style>
