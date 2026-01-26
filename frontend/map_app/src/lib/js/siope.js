export async function getSiopePayroll(cityId, year) {
  const queryUrl = `/api/query/siope?city=${cityId}&year=${year}`;

  // --- 1. TENTATIVA DE LEITURA (GET) ---
  console.log(`1. Tentando GET: ${queryUrl}`);
  let response = await fetch(queryUrl);

  if (response.status == 200) {
    // Status 200 OK: Dados encontrados no cache/DB
    console.log("✅ Dados prontos (Status 200 OK).");
    return await response.json();
  } else if (response.status === 204 || response.status === 404) {
    // Status 204 No Content / 404 Not Found: Os dados não existem (ainda).
    console.log(
      `2. Dados não encontrados (Status ${response.status}). Iniciando job...`,
    );

    // --- 2. INICIAÇÃO DO JOB (POST) ---
    return await startSiopeJob(cityId, year);
  } else {
    // Tratar outros erros (500, etc.)
    throw new Error(
      `Erro ao buscar dados: ${response.status} ${response.statusText}`,
    );
  }
}

export async function startSiopeJob(cityId, year) {
  const jobUrl = `/api/jobs/siope`;

  console.log(`3. Enviando POST para iniciar job: ${jobUrl}`);

  // O POST envia os mesmos parâmetros para que o backend crie o job
  let postResponse = await fetch(jobUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ city: cityId, year: year }),
  });

  if (postResponse.status === 202) {
    // Status 202 Accepted: Job iniciado com sucesso
    const jobInfo = await postResponse.json();
    const jobId = jobInfo.job_id;

    console.log(`4. Job aceito (Status 202). Job ID: ${jobId}`);
    return jobId;
  } else {
    throw new Error(
      `Erro ao iniciar o job: ${postResponse.status} ${postResponse.statusText}`,
    );
  }
}

export function monitorJobProgress(progressUrl, updateCallback, errorCallback) {
  const eventSource = new EventSource(progressUrl);

  eventSource.addEventListener('progress', (event) => {
    try {
      const data = JSON.parse(event.data);
      updateCallback(data);
    } catch (e) {
      console.error("Erro ao parsear mensagem SSE:", e);
    }
  });

  eventSource.onerror = (err) => {
    errorCallback(new Error("Falha na conexão de monitoramento SSE."));
    eventSource.close();
  };

  // Retorna a função de limpeza
  return () => eventSource.close();
}

export function formatValue(key, value) {
  if (value === null) return "N/A";

  switch (key) {
    case "area":
      return Number(value).toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });
    case "codigo_municipio":
    case "codigo_unidade_federativa":
      return `"${value}"`;
    default:
      return String(value);
  }
}
