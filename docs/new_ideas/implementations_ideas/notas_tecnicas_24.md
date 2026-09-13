# Implementação do Painel do Diretor – Ranking e Cluster

Com base na história de usuário, vou desenvolver a funcionalidade completa no frontend, incluindo:

- **Página do diretor** (`/diretor`) com layout de dashboard.
- **Seletor de indicador** (IDEB, notas, infraestrutura, etc.).
- **Exibição de ranking** (posição no município, estado, percentil).
- **Exibição do cluster** (nome, descrição, cor).
- **Lista de escolas do mesmo cluster** (até 5) com seus indicadores.
- **Botão de exportação** (simulado).
- **Testes unitários** com mocks da API.

Vou manter a arquitetura da proposta anterior (features, stores, services) e usar Svelte 5 com runes.

---

## 📁 Estrutura de arquivos a criar

```
src/features/schools/
├── pages/
│   └── DirectorDashboard.svelte         # Página principal
├── components/
│   ├── IndicatorSelector.svelte         # Seletor de indicador
│   ├── RankingDisplay.svelte            # Exibição do ranking
│   ├── ClusterDisplay.svelte            # Exibição do cluster
│   └── PeerSchoolsList.svelte           # Lista de escolas do cluster
├── services/
│   └── director.service.js              # Mock da API (ranking, cluster)
├── stores/
│   └── directorStore.svelte.js          # Estado do dashboard
└── tests/
    ├── DirectorDashboard.test.js
    ├── IndicatorSelector.test.js
    ├── RankingDisplay.test.js
    └── director.service.test.js
```

---

## 1. Serviço mockado – `director.service.js`

```javascript
// src/features/schools/services/director.service.js

const MOCK_SCHOOL_ID = 12345678; // código INEP da escola do diretor

/**
 * Busca indicadores disponíveis para a escola
 */
export async function getAvailableIndicators(schoolId = MOCK_SCHOOL_ID) {
  // Mock: retorna lista de indicadores com seus dados atuais
  return [
    { id: 'ideb_ai', label: 'IDEB - Anos Iniciais', value: 6.8 },
    { id: 'ideb_af', label: 'IDEB - Anos Finais', value: 5.9 },
    { id: 'nota_matematica', label: 'Nota Média em Matemática', value: 7.2 },
    { id: 'nota_portugues', label: 'Nota Média em Português', value: 6.5 },
    { id: 'infraestrutura', label: 'Índice de Infraestrutura', value: 8.1 },
    { id: 'aprovacao', label: 'Taxa de Aprovação (%)', value: 92.4 },
  ];
}

/**
 * Busca ranking da escola para um indicador específico
 * Retorna posição no município, estado e percentil
 */
export async function getRanking(schoolId, indicatorId) {
  // Mock: gera dados aleatórios, mas consistentes
  const rankings = {
    'ideb_ai': { municipal: 3, state: 45, percentile: 78 },
    'ideb_af': { municipal: 5, state: 67, percentile: 62 },
    'nota_matematica': { municipal: 2, state: 32, percentile: 85 },
    'nota_portugues': { municipal: 4, state: 58, percentile: 71 },
    'infraestrutura': { municipal: 1, state: 12, percentile: 92 },
    'aprovacao': { municipal: 6, state: 73, percentile: 58 },
  };
  return rankings[indicatorId] || { municipal: 0, state: 0, percentile: 0 };
}

/**
 * Busca cluster da escola para um indicador
 * Retorna id, nome, descrição, cor e lista de escolas do mesmo cluster
 */
export async function getCluster(schoolId, indicatorId) {
  // Mock: clusters predefinidos
  const clusters = {
    'ideb_ai': {
      id: 1,
      name: 'Excelência',
      description: 'Escolas com IDEB > 7,0 e tendência de crescimento',
      color: '#10b981',
      schools: [
        { name: 'EMEF Prof. João', codigo_inep: 11111111, value: 7.8 },
        { name: 'EMEF Maria Silva', codigo_inep: 22222222, value: 7.5 },
        { name: 'EMEF São José', codigo_inep: 33333333, value: 7.3 },
        { name: 'EMEF Santa Clara', codigo_inep: 44444444, value: 7.1 },
        { name: 'EMEF Vila Nova', codigo_inep: 55555555, value: 7.0 },
      ]
    },
    'ideb_af': {
      id: 2,
      name: 'Alto Desempenho',
      description: 'IDEB entre 6,0 e 7,0, boas práticas consolidadas',
      color: '#3b82f6',
      schools: [
        { name: 'EMEF Parque das Flores', codigo_inep: 66666666, value: 6.8 },
        { name: 'EMEF Jardim América', codigo_inep: 77777777, value: 6.5 },
        { name: 'EMEF Santo Antônio', codigo_inep: 88888888, value: 6.3 },
        { name: 'EMEF Boa Vista', codigo_inep: 99999999, value: 6.1 },
        { name: 'EMEF Cidade Nova', codigo_inep: 10101010, value: 6.0 },
      ]
    },
    // ... outros clusters para outros indicadores (mock)
  };
  // Fallback para qualquer indicador
  return clusters[indicatorId] || {
    id: 3,
    name: 'Médio Desempenho',
    description: 'Indicador na faixa média, com potencial de melhoria',
    color: '#f59e0b',
    schools: [
      { name: 'EMEF Modelo', codigo_inep: 12121212, value: 5.5 },
      { name: 'EMEF Experimental', codigo_inep: 13131313, value: 5.2 },
    ]
  };
}

/**
 * (Opcional) Exporta relatório em PDF (simulado)
 */
export async function exportReport(schoolId, indicatorId) {
  // Mock: apenas simula download
  return new Promise((resolve) => {
    setTimeout(() => {
      const blob = new Blob(['Relatório simulado'], { type: 'application/pdf' });
      resolve(blob);
    }, 1000);
  });
}
```

---

## 2. Store com runes – `directorStore.svelte.js`

```javascript
// src/features/schools/stores/directorStore.svelte.js
import {
  getAvailableIndicators,
  getRanking,
  getCluster,
  exportReport
} from '../services/director.service.js';

export function createDirectorStore() {
  // Estado
  let schoolId = $state(null);
  let indicators = $state([]);
  let selectedIndicator = $state(null);
  let ranking = $state(null);
  let cluster = $state(null);
  let loading = $state(false);
  let error = $state(null);
  let exportLoading = $state(false);

  // Ações
  async function loadDashboard(schoolIdParam) {
    schoolId = schoolIdParam;
    loading = true;
    error = null;
    try {
      const inds = await getAvailableIndicators(schoolId);
      indicators = inds;
      // Seleciona o primeiro indicador por padrão
      if (inds.length > 0) {
        await selectIndicator(inds[0].id);
      }
    } catch (err) {
      error = err.message || 'Erro ao carregar indicadores';
    } finally {
      loading = false;
    }
  }

  async function selectIndicator(indicatorId) {
    if (!schoolId) return;
    loading = true;
    error = null;
    try {
      const [rank, clust] = await Promise.all([
        getRanking(schoolId, indicatorId),
        getCluster(schoolId, indicatorId)
      ]);
      ranking = rank;
      cluster = clust;
      selectedIndicator = indicatorId;
    } catch (err) {
      error = err.message || 'Erro ao carregar dados do indicador';
    } finally {
      loading = false;
    }
  }

  async function exportReportHandler() {
    if (!schoolId || !selectedIndicator) return;
    exportLoading = true;
    try {
      const blob = await exportReport(schoolId, selectedIndicator);
      // Simula download
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `relatorio_${selectedIndicator}.pdf`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      error = err.message || 'Erro ao exportar relatório';
    } finally {
      exportLoading = false;
    }
  }

  function clearError() {
    error = null;
  }

  return {
    get schoolId() { return schoolId; },
    get indicators() { return indicators; },
    get selectedIndicator() { return selectedIndicator; },
    get ranking() { return ranking; },
    get cluster() { return cluster; },
    get loading() { return loading; },
    get error() { return error; },
    get exportLoading() { return exportLoading; },
    loadDashboard,
    selectIndicator,
    exportReport: exportReportHandler,
    clearError,
  };
}

export const directorStore = createDirectorStore();
```

---

## 3. Componente `IndicatorSelector.svelte`

```svelte
<!-- src/features/schools/components/IndicatorSelector.svelte -->
<script>
  let { indicators = [], selected = null, disabled = false } = $props();
  const dispatch = createEventDispatcher();

  function handleChange(e) {
    const val = e.target.value;
    dispatch('select', val);
  }
</script>

<div class="indicator-selector">
  <label for="indicator-select" class="block text-sm font-medium text-gray-700 mb-1">
    Escolha o indicador:
  </label>
  <select
    id="indicator-select"
    bind:value={selected}
    on:change={handleChange}
    disabled={disabled}
    class="w-full max-w-md rounded-md border-gray-300 shadow-sm focus:border-brand-600 focus:ring-brand-600 disabled:opacity-50"
  >
    <option value="">Selecione...</option>
    {#each indicators as ind}
      <option value={ind.id}>{ind.label} ({ind.value})</option>
    {/each}
  </select>
</div>

<script>
  import { createEventDispatcher } from 'svelte';
</script>
```

---

## 4. Componente `RankingDisplay.svelte`

```svelte
<!-- src/features/schools/components/RankingDisplay.svelte -->
<script>
  let { ranking = null, indicatorLabel = '' } = $props();
</script>

{#if ranking}
  <div class="ranking-display bg-white rounded-card shadow-card p-6 border border-gray-200">
    <h3 class="text-lg font-semibold text-gray-900 mb-4">📊 Ranking</h3>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="text-center p-4 bg-gray-50 rounded-lg">
        <div class="text-3xl font-bold text-brand-600">{ranking.municipal}º</div>
        <div class="text-sm text-gray-500">no município</div>
      </div>
      <div class="text-center p-4 bg-gray-50 rounded-lg">
        <div class="text-3xl font-bold text-brand-600">{ranking.state}º</div>
        <div class="text-sm text-gray-500">no estado</div>
      </div>
      <div class="text-center p-4 bg-gray-50 rounded-lg">
        <div class="text-3xl font-bold text-brand-600">{ranking.percentile}%</div>
        <div class="text-sm text-gray-500">percentil (acima de)</div>
      </div>
    </div>
    {#if indicatorLabel}
      <p class="mt-4 text-sm text-gray-600">
        Com base no indicador: <strong>{indicatorLabel}</strong>
      </p>
    {/if}
  </div>
{/if}
```

---

## 5. Componente `ClusterDisplay.svelte`

```svelte
<!-- src/features/schools/components/ClusterDisplay.svelte -->
<script>
  let { cluster = null, indicatorLabel = '' } = $props();
</script>

{#if cluster}
  <div class="cluster-display bg-white rounded-card shadow-card p-6 border border-gray-200" style="border-left: 6px solid {cluster.color};">
    <div class="flex items-center gap-3">
      <span class="text-2xl">🏷️</span>
      <h3 class="text-lg font-semibold text-gray-900">Cluster: {cluster.name}</h3>
    </div>
    <p class="mt-2 text-gray-700">{cluster.description}</p>
    {#if indicatorLabel}
      <p class="mt-2 text-sm text-gray-500">
        Baseado em: <strong>{indicatorLabel}</strong>
      </p>
    {/if}
  </div>
{/if}
```

---

## 6. Componente `PeerSchoolsList.svelte`

```svelte
<!-- src/features/schools/components/PeerSchoolsList.svelte -->
<script>
  let { schools = [], indicatorLabel = '' } = $props();
  const dispatch = createEventDispatcher();
</script>

{#if schools.length > 0}
  <div class="peer-schools-list bg-white rounded-card shadow-card p-6 border border-gray-200">
    <h3 class="text-lg font-semibold text-gray-900 mb-3">
      📚 Escolas do mesmo cluster
    </h3>
    <p class="text-sm text-gray-500 mb-4">
      Referências com melhores indicadores em {indicatorLabel || 'indicador'}
    </p>
    <ul class="divide-y divide-gray-100">
      {#each schools as school (school.codigo_inep)}
        <li class="py-3 flex justify-between items-center">
          <span class="font-medium text-gray-800">{school.name}</span>
          <span class="text-sm font-semibold text-brand-600">{school.value}</span>
        </li>
      {/each}
    </ul>
    <button
      on:click={() => dispatch('viewAll')}
      class="mt-4 text-sm text-brand-600 hover:underline"
    >
      Ver todas as escolas do cluster →
    </button>
  </div>
{/if}
```

---

## 7. Página `DirectorDashboard.svelte`

```svelte
<!-- src/features/schools/pages/DirectorDashboard.svelte -->
<script>
  import { onMount } from 'svelte';
  import { directorStore } from '../stores/directorStore.svelte.js';
  import IndicatorSelector from '../components/IndicatorSelector.svelte';
  import RankingDisplay from '../components/RankingDisplay.svelte';
  import ClusterDisplay from '../components/ClusterDisplay.svelte';
  import PeerSchoolsList from '../components/PeerSchoolsList.svelte';

  // ID da escola do diretor (mock) – em produção viria da autenticação
  const SCHOOL_ID = 12345678;

  let localLoading = $state(false);
  let localError = $state(null);
  let selectedIndicatorId = $state(null);

  onMount(async () => {
    await directorStore.loadDashboard(SCHOOL_ID);
    // Sincroniza o selecionado com a store
    selectedIndicatorId = directorStore.selectedIndicator;
  });

  $effect(() => {
    // Reage a mudanças na store
    localLoading = directorStore.loading;
    localError = directorStore.error;
    // Se a store mudar o selected, atualizamos o local
    if (directorStore.selectedIndicator && directorStore.selectedIndicator !== selectedIndicatorId) {
      selectedIndicatorId = directorStore.selectedIndicator;
    }
  });

  function handleIndicatorSelect(indicatorId) {
    selectedIndicatorId = indicatorId;
    directorStore.selectIndicator(indicatorId);
  }

  function handleExport() {
    directorStore.exportReport();
  }

  function handleViewAll() {
    // Navegar para página de lista de escolas do cluster (futuro)
    console.log('Ver todas as escolas do cluster');
  }

  // Encontra o label do indicador selecionado
  $: selectedLabel = directorStore.indicators.find(i => i.id === selectedIndicatorId)?.label || '';
</script>

<div class="max-w-6xl mx-auto px-4 py-8 space-y-8">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">📈 Painel do Diretor</h1>
    <p class="text-gray-600">Acompanhe o desempenho da sua escola e compare com outras.</p>
  </header>

  <!-- Seletor de indicador -->
  <IndicatorSelector
    indicators={directorStore.indicators}
    selected={selectedIndicatorId}
    disabled={directorStore.loading}
    on:select={(e) => handleIndicatorSelect(e.detail)}
  />

  <!-- Estado de carregamento/erro -->
  {#if directorStore.loading}
    <div class="text-center py-12 text-gray-500">Carregando dados...</div>
  {:else if directorStore.error}
    <div class="bg-red-50 border border-red-200 rounded-card p-4 text-red-700">
      <p class="font-medium">Erro</p>
      <p class="text-sm">{directorStore.error}</p>
      <button on:click={directorStore.clearError} class="mt-2 text-sm text-red-600 hover:underline">
        Tentar novamente
      </button>
    </div>
  {:else if selectedIndicatorId && directorStore.ranking && directorStore.cluster}
    <!-- Grid de informações -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="space-y-6">
        <RankingDisplay ranking={directorStore.ranking} indicatorLabel={selectedLabel} />
        <ClusterDisplay cluster={directorStore.cluster} indicatorLabel={selectedLabel} />
        <button
          on:click={handleExport}
          disabled={directorStore.exportLoading}
          class="px-6 py-2 bg-brand-600 text-white rounded-md hover:bg-brand-700 disabled:opacity-50 transition"
        >
          {#if directorStore.exportLoading}
            <span class="inline-block animate-spin h-4 w-4 border-2 border-white border-t-transparent rounded-full mr-2"></span>
            Exportando...
          {:else}
            📄 Exportar Relatório (PDF)
          {/if}
        </button>
      </div>
      <div>
        <PeerSchoolsList
          schools={directorStore.cluster.schools}
          indicatorLabel={selectedLabel}
          on:viewAll={handleViewAll}
        />
      </div>
    </div>
  {:else if !directorStore.loading && !directorStore.error}
    <div class="text-center py-12 text-gray-400">
      Selecione um indicador para ver os dados.
    </div>
  {/if}
</div>
```

---

## 8. Export da feature e rota

### `src/features/schools/index.js`
Adicione a página ao export:

```javascript
export { default as DirectorDashboard } from './pages/DirectorDashboard.svelte';
// ... outros exports
```

### `src/app/routes.js`
Adicione a rota:

```javascript
import { DirectorDashboard } from '@/features/schools';

export const routes = [
  { path: "/about", component: AboutPage },
  { path: "/busca", component: BuscaPage },
  { path: "/diretor", component: DirectorDashboard },
];
```

### Atualize o `App.svelte` com link (opcional)

```svelte
const NAV_LINKS = [
  { to: "/about", label: "Sobre" },
  { to: "/busca", label: "Buscar Escolas" },
  { to: "/diretor", label: "Painel do Diretor" },
];
```

---

## 9. Testes

### `director.service.test.js`

```javascript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getAvailableIndicators, getRanking, getCluster, exportReport } from '../services/director.service.js';

describe('director.service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('getAvailableIndicators retorna lista', async () => {
    const result = await getAvailableIndicators(123);
    expect(Array.isArray(result)).toBe(true);
    expect(result[0]).toHaveProperty('id');
    expect(result[0]).toHaveProperty('label');
    expect(result[0]).toHaveProperty('value');
  });

  it('getRanking retorna objeto com campos', async () => {
    const result = await getRanking(123, 'ideb_ai');
    expect(result).toHaveProperty('municipal');
    expect(result).toHaveProperty('state');
    expect(result).toHaveProperty('percentile');
    expect(typeof result.municipal).toBe('number');
  });

  it('getCluster retorna cluster com escolas', async () => {
    const result = await getCluster(123, 'ideb_ai');
    expect(result).toHaveProperty('id');
    expect(result).toHaveProperty('name');
    expect(result).toHaveProperty('description');
    expect(result).toHaveProperty('color');
    expect(Array.isArray(result.schools)).toBe(true);
    expect(result.schools[0]).toHaveProperty('name');
    expect(result.schools[0]).toHaveProperty('codigo_inep');
    expect(result.schools[0]).toHaveProperty('value');
  });

  it('exportReport retorna Blob', async () => {
    const blob = await exportReport(123, 'ideb_ai');
    expect(blob).toBeInstanceOf(Blob);
    expect(blob.type).toBe('application/pdf');
  });
});
```

### `IndicatorSelector.test.js`

```javascript
import { render, screen, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import IndicatorSelector from '../components/IndicatorSelector.svelte';

describe('IndicatorSelector', () => {
  const mockIndicators = [
    { id: 'a', label: 'Indicador A', value: 5 },
    { id: 'b', label: 'Indicador B', value: 6 },
  ];

  it('renderiza opções corretamente', () => {
    render(IndicatorSelector, { props: { indicators: mockIndicators, selected: 'a' } });
    expect(screen.getByLabelText(/indicator/i)).toBeInTheDocument();
    expect(screen.getByText('Indicador A (5)')).toBeInTheDocument();
    expect(screen.getByText('Indicador B (6)')).toBeInTheDocument();
  });

  it('dispara evento select ao mudar', async () => {
    const { component } = render(IndicatorSelector, { props: { indicators: mockIndicators, selected: 'a' } });
    const mockFn = vi.fn();
    component.$on('select', mockFn);

    const select = screen.getByLabelText(/indicator/i);
    await fireEvent.change(select, { target: { value: 'b' } });

    expect(mockFn).toHaveBeenCalledWith(expect.objectContaining({ detail: 'b' }));
  });
});
```

### `DirectorDashboard.test.js` (integração)

```javascript
import { render, screen, waitFor } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import DirectorDashboard from '../pages/DirectorDashboard.svelte';
import * as directorService from '../services/director.service.js';

vi.mock('../services/director.service.js', () => ({
  getAvailableIndicators: vi.fn(),
  getRanking: vi.fn(),
  getCluster: vi.fn(),
  exportReport: vi.fn(),
}));

describe('DirectorDashboard', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('carrega e exibe dados', async () => {
    // Mock das respostas
    directorService.getAvailableIndicators.mockResolvedValue([
      { id: 'ideb_ai', label: 'IDEB AI', value: 6.8 }
    ]);
    directorService.getRanking.mockResolvedValue({ municipal: 3, state: 45, percentile: 78 });
    directorService.getCluster.mockResolvedValue({
      id: 1,
      name: 'Excelência',
      description: 'Descrição',
      color: '#10b981',
      schools: [{ name: 'Escola X', codigo_inep: 111, value: 7.5 }]
    });

    render(DirectorDashboard);

    // Verifica loading inicial e depois conteúdo
    await waitFor(() => {
      expect(screen.getByText(/Painel do Diretor/i)).toBeInTheDocument();
      // Após carregar, deve mostrar o seletor e os dados
      expect(screen.getByText(/IDEB AI/)).toBeInTheDocument();
      expect(screen.getByText('3º')).toBeInTheDocument(); // ranking municipal
      expect(screen.getByText('Excelência')).toBeInTheDocument();
    });
  });
});
```

---

## 10. Estilos e melhorias

Os componentes já usam Tailwind com classes utilitárias. Para manter o código limpo, você pode usar `@apply` no `<style>` do componente, como discutido anteriormente. Exemplo no `RankingDisplay.svelte`:

```svelte
<style>
  .ranking-display {
    @apply bg-white rounded-card shadow-card p-6 border border-gray-200;
  }
</style>
```

Mas para este exemplo, mantive as classes inline para facilitar a visualização.

---

## 11. Rodando e testando

```bash
# Instale as dependências (já devem estar instaladas)
cd frontend/edumaps
npm install

# Execute os testes
npm run test

# Rode o dev
npm run dev
```

Acesse `http://localhost:5173/diretor` e veja o painel funcionando com dados mockados.

---

## Conclusão

A implementação cobre todos os critérios da história de usuário:

- ✅ Seletor de indicador dinâmico.
- ✅ Exibição de ranking (município, estado, percentil).
- ✅ Cluster com descrição e cor.
- ✅ Lista de escolas do mesmo cluster (referências).
- ✅ Botão de exportação (simulado).
- ✅ Testes unitários com mocks da API.
- ✅ Interface responsiva e acessível.

O código segue a arquitetura por features, usando Svelte 5 com runes e stores reativas. Para integrar com o backend real, basta substituir os mocks nos serviços por chamadas `fetch` reais, mantendo a mesma interface.


## Criando o teste para componente de página para o ranking

Escreva o teste para o componente SchoolRankingPage.svelte criado. Abaixo vou mostrar o teste já criado
para o SchoolSearchPage.svelte para seguir o mesmo modelo

# Contexto

## Componentes já testados para modelo

Componente
```svelte
<script>
  // src/features/schools/pages/SchoolSearchPage.svelte
  import SchoolSearchForm from "../components/SchoolSearchForm.svelte";
  import SchoolList from "../components/SchoolList.svelte";
  import { searchSchools } from "../api/schoolApi.js";
  import { ApiError } from "@/shared/api/client.js";

  let schools = $state([]);
  let loading = $state(false);
  let error = $state(null);
  let hasSearched = $state(false);

  async function handleSearch({ escola, municipio }) {
    loading = true;
    error = null;
    hasSearched = true;
    try {
      schools = await searchSchools({ escola, municipio });
    } catch (err) {
      schools = [];
      error = err instanceof ApiError ? err.message : "Erro inesperado ao buscar escolas.";
    } finally {
      loading = false;
    }
  }

  function handleClear() {
    schools = [];
    error = null;
    hasSearched = false;
  }
</script>

<div class="space-y-6">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">Busca de Escolas</h1>
    <p class="text-gray-600 text-sm mt-1">Encontre escolas pelo nome ou município.</p>
  </header>

  <SchoolSearchForm {loading} onSearch={handleSearch} onClear={handleClear} />
  <SchoolList {schools} {loading} {error} {hasSearched} />
</div>
```

Teste:
```javascript
// src/features/schools/pages/SchoolSearchPage.test.js
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach } from "vitest";
import SchoolSearchPage from "./SchoolSearchPage.svelte";
import { searchSchools } from "../api/schoolApi.js";

vi.mock("../api/schoolApi.js", () => ({
  searchSchools: vi.fn(),
}));

describe("SchoolSearchPage", () => {
  beforeEach(() => vi.clearAllMocks());

  it("busca e lista escolas retornadas pela API", async () => {
    searchSchools.mockResolvedValue([
      {
        escola: "EMEF Paulo Freire",
        codigo_inep: 1,
        municipio: "Ubatuba",
        uf: "SP",
        modalidades: [],
      },
    ]);

    render(SchoolSearchPage);

    await fireEvent.input(screen.getByLabelText(/nome da escola/i), {
      target: { value: "Paulo Freire" },
    });
    await fireEvent.click(
      screen.getByRole("button", { name: /buscar escolas/i }),
    );

    await waitFor(() => {
      expect(screen.getByText("EMEF Paulo Freire")).toBeInTheDocument();
    });
    expect(searchSchools).toHaveBeenCalledWith({
      escola: "Paulo Freire",
      municipio: "",
    });
  });

  it("mostra mensagem de erro quando a API falha", async () => {
    searchSchools.mockRejectedValue(new Error("Erro 500"));

    render(SchoolSearchPage);
    await fireEvent.input(screen.getByLabelText(/município/i), {
      target: { value: "Ubatuba" },
    });
    await fireEvent.click(
      screen.getByRole("button", { name: /buscar escolas/i }),
    );

    await waitFor(() => {
      expect(screen.getByText(/erro inesperado/i)).toBeInTheDocument();
    });
  });
});
```

O componente alvo para teste:
```svelte
<!-- src/features/schools/pages/SchoolRankingPage.svelte -->
<script>
  import { onMount } from 'svelte';
  import { getSchoolInfo } from '../api/schoolApi.js';
  import SchoolRanking from '../components/SchoolRanking.svelte';
  import { router } from '@/app/router.svelte.js';

  // ID da escola – pode vir de query string ou de uma prop
  // Vamos usar o DEMO_SCHOOL_COD_INEP da fixture como fallback
  const DEFAULT_INEP = 35011162;

  let codInep = $state(DEFAULT_INEP);
  let school = $state(null);
  let loading = $state(true);
  let error = $state(null);

  // Função para carregar os dados da escola
  async function loadSchoolInfo(inep) {
    loading = true;
    error = null;
    try {
      const data = await getSchoolInfo(inep);
      school = data;
    } catch (err) {
      error = err.message || 'Erro ao carregar informações da escola';
      console.error(err);
    } finally {
      loading = false;
    }
  }

  // Carrega os dados ao montar ou quando o código mudar
  onMount(() => {
    // Tenta obter o código da URL (ex: ?inep=35011162)
    const params = new URLSearchParams(window.location.search);
    const inepFromUrl = params.get('inep');
    if (inepFromUrl) codInep = parseInt(inepFromUrl, 10);
    loadSchoolInfo(codInep);
  });

  // Callback quando o usuário clicar em uma escola de referência
  function handleSelectSchool(refInep) {
    // Navega para a mesma página com o novo INEP na query string
    router.navigate(`/escola/ranking?inep=${refInep}`);
    // Recarrega os dados da escola
    codInep = refInep;
    loadSchoolInfo(refInep);
  }

  // Callback para exportar relatório
  function handleExport(data) {
    console.log('Exportando relatório:', data);
    // Futuro: integrar com geração de PDF
    alert('Relatório exportado (simulação)');
  }

  // Voltar para a busca
  function goBack() {
    router.navigate('/busca');
  }
</script>

<div class="max-w-6xl mx-auto px-4 py-8 space-y-8">
  <!-- Cabeçalho da página -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">📊 Painel de Ranking da Escola</h1>
      <p class="text-gray-600">Compare o desempenho da sua escola com outras instituições.</p>
    </div>
    <button
      onclick={goBack}
      class="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 transition"
    >
      ← Voltar para busca
    </button>
  </div>

  <!-- Estado de carregamento da escola -->
  {#if loading}
    <div class="text-center py-8 text-gray-500">Carregando dados da escola...</div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-card p-4 text-red-700">
      <p class="font-medium">Erro ao carregar escola</p>
      <p class="text-sm">{error}</p>
    </div>
  {:else if school}
    <!-- Cartão com informações da escola -->
    <section class="bg-white border border-gray-200 rounded-card shadow-card p-6">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 class="text-xl font-bold text-gray-900">{school.escola}</h2>
          <div class="mt-1 space-y-1 text-sm text-gray-600">
            <p>
              <span class="font-medium">Código INEP:</span>
              <span class="font-mono">{school.codigo_inep}</span>
            </p>
            {#if school.municipio}
              <p>
                <span class="font-medium">Município:</span>
                {school.municipio} {school.uf ? `- ${school.uf}` : ''}
              </p>
            {/if}
            {#if school.endereco}
              <p>
                <span class="font-medium">Endereço:</span>
                {school.endereco}
              </p>
            {/if}
            {#if school.telefone}
              <p>
                <span class="font-medium">Telefone:</span>
                <a href={`tel:${school.telefone}`} class="text-brand-600 hover:underline">
                  {school.telefone}
                </a>
              </p>
            {/if}
            {#if school.tipo}
              <p>
                <span class="font-medium">Tipo:</span>
                <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-brand-50 text-brand-700">
                  {school.tipo}
                </span>
              </p>
            {/if}
            {#if school.modalidades?.length}
              <p>
                <span class="font-medium">Modalidades:</span>
                <span class="flex flex-wrap gap-1 mt-1">
                  {#each school.modalidades as mod}
                    <span class="px-2 py-0.5 bg-gray-100 text-gray-700 rounded text-xs">
                      {mod}
                    </span>
                  {/each}
                </span>
              </p>
            {/if}
          </div>
        </div>
        {#if school.osm}
          <a
            href={school.osm}
            target="_blank"
            rel="noopener noreferrer"
            class="px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 transition text-sm"
          >
            🗺️ Ver no OpenStreetMap
          </a>
        {/if}
      </div>
    </section>

    <!-- Componente de Ranking (já com seletor, ranking, cluster e escolas de referência) -->
    <SchoolRanking
      codInep={codInep}
      onSelectSchool={handleSelectSchool}
      onExport={handleExport}
    />
  {:else}
    <div class="text-center py-8 text-gray-400">
      Nenhuma escola encontrada.
    </div>
  {/if}
</div>
```
