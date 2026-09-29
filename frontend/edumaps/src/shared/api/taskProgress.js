// src/shared/api/taskProgress.js
//
// Acompanhamento de jobs Minion (backend EduMaps) por SSE, com snapshot
// final para decidir sucesso/erro. Extraído de schools/api para reuso por
// qualquer feature que dispare tasks (SIOPE, OSM, clusterização...).
import { apiClient } from "@/shared/api/client.js";

/** Snapshot do job (polling simples). @returns {Promise<{state:string, error?:string}>} */
export function getJobProgress(jobId) {
  return apiClient.get("/api/task/progress", { job_id: jobId });
}

/**
 * Acompanha o job por SSE (Server-Sent Events) e, ao encerrar o stream, lê o
 * snapshot final (o SSE não emite falha) para decidir sucesso/erro.
 * @param {string|number} jobId
 * @param {{ onProgress?: (p:object)=>void, onDone?: ()=>void, onError?: (msg:string)=>void }} handlers
 * @returns {() => void} função para cancelar
 */
export function watchJobProgress(jobId, { onProgress, onDone, onError } = {}) {
  let encerrado = false;
  const source = new EventSource(`/api/task/progress?job_id=${jobId}`);

  const finalizar = async () => {
    source.close();
    try {
      const snap = await getJobProgress(jobId);
      if (snap.state === "failed") {
        onError?.(snap.error || "A tarefa falhou.");
      } else {
        onDone?.();
      }
    } catch (err) {
      onError?.(err instanceof Error ? err.message : "Falha ao acompanhar a tarefa.");
    }
  };

  source.onmessage = (event) => {
    try {
      onProgress?.(JSON.parse(event.data));
    } catch {
      // evento sem JSON — ignora
    }
  };

  source.onerror = () => {
    if (encerrado) return;
    encerrado = true;
    finalizar();
  };

  return () => {
    encerrado = true;
    source.close();
  };
}
