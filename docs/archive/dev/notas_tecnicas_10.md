Excelente escolha em seguir com o **Vitest**! Para testar componentes Svelte modernos, a combinação ideal é o **Vitest** + **Svelte Testing Library** (`@testing-library/svelte`) + **msw** (Mock Service Worker) para interceptar as requisições de API de forma limpa.

Como os seus arquivos de teste atuais estão centralizados na pasta `src/tests/`, vamos criar uma nova estrutura de testes focada no comportamento desse fluxo de Scores.

Vamos criar dois arquivos de teste principais:

1. **`src/tests/ScoresModal.test.js`**: Para testar isoladamente os estados do modal (carregando, sucesso, erro e reatividade do Svelte).
2. **`src/tests/SchoolScores.test.js`**: Para testar se as regras de negócio (as cores das barras com base na nota e a exibição das médias) estão corretas.

---

### 1. Configuração Prévia (Mock do Serviço)

Para garantir que o `ScoresModal` chame a API corretamente sem bater no servidor real, nós vamos mockar a função `fetchSchoolScores`.

Crie ou atualize o seu arquivo de testes do modal mockando o módulo `../service/school.js`.

---

### 2. Testando o `ScoresModal.svelte`

O comportamento deste componente é fortemente guiado por reatividade (`$: if (isOpen ...)`). Precisamos testar:

* Se ele não renderiza nada se estiver fechado.
* Se mostra o estado de *Loading* ao abrir.
* Se renderiza os dados após a API responder.
* Se renderiza a mensagem de erro caso a API falhe.

Crie o arquivo **`src/tests/ScoresModal.test.js`**:

```javascript
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import ScoresModal from '../lib/School/ScoresModal.svelte';
import { fetchSchoolScores } from '../lib/service/school.js';

// Mock do serviço de busca de scores
vi.mock('../lib/service/school.js', () => ({
  fetchSchoolScores: vi.fn()
}));

describe('ScoresModal Component', () => {
  const mockEscola = {
    codigo_inep: '123456',
    escola: 'Escola Modelo de Teste',
    endereco: 'Rua dos Testes, 123'
  };

  const mockScoreData = {
    co_entidade: '123456',
    nu_ano_censo: '2026',
    data_atualizacao: '2026-06-07T14:00:00Z',
    score_infraestrutura: '8.5',
    score_capacitacao_docente: '5.2'
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('não deve renderizar o modal se isOpen for false', () => {
    const { container } = render(ScoresModal, { escola: mockEscola, isOpen: false });
    expect(container.innerHTML).toBe('');
  });

  it('deve exibir o estado de loading e chamar a API ao abrir', async () => {
    // Força a API a demorar um pouco para pegarmos o estado de loading
    fetchSchoolScores.mockReturnValue(new Promise(() => {}));

    render(ScoresModal, { escola: mockEscola, isOpen: true });

    expect(screen.getByText('Carregando scores...')).toBeInTheDocument();
    expect(fetchSchoolScores).toHaveBeenCalledWith('123456');
  });

  it('deve renderizar o SchoolScores após o carregamento com sucesso', async () => {
    fetchSchoolScores.mockResolvedValue(mockScoreData);

    render(ScoresModal, { escola: mockEscola, isOpen: true });

    // Espera o loading sumir e o nome da escola (renderizado pelo SchoolScores) aparecer
    await waitFor(() => {
      expect(screen.queryByText('Carregando scores...')).not.toBeInTheDocument();
    });

    expect(screen.getByText('Escola Modelo de Teste')).toBeInTheDocument();
  });

  it('deve exibir mensagem de erro e permitir tentar novamente se a API falhar', async () => {
    fetchSchoolScores.mockRejectedValueOnce(new Error('Falha na conexão'));

    render(ScoresModal, { escola: mockEscola, isOpen: true });

    await waitFor(() => {
      expect(screen.getByText('Erro ao carregar os scores: Falha na conexão')).toBeInTheDocument();
    });

    // Testar o botão "Tentar novamente"
    fetchSchoolScores.mockResolvedValueOnce(mockScoreData);
    const retryBtn = screen.getByRole('button', { name: /tentar novamente/i });
    await fireEvent.click(retryBtn);

    await waitFor(() => {
      expect(screen.getByText('Escola Modelo de Teste')).toBeInTheDocument();
    });
  });

  it('deve disparar o evento "close" ao clicar no botão fechar', async () => {
    fetchSchoolScores.mockResolvedValue(mockScoreData);
    const { component } = render(ScoresModal, { escola: mockEscola, isOpen: true });
    
    const mockCloseHandler = vi.fn();
    component.$on('close', mockCloseHandler);

    const closeBtn = screen.getByText('✕');
    await fireEvent.click(closeBtn);

    expect(mockCloseHandler).toHaveBeenCalled();
  });
});

```

---

### 3. Testando o `SchoolScores.svelte`

Aqui mora a lógica visual do seu app: as regras do método `getBarColor` (vermelho se < 3, amarelo se < 6, etc.) e a condicional de exibição das médias (`averages`).

Crie o arquivo **`src/tests/SchoolScores.test.js`**:

```javascript
import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import SchoolScores from '../lib/School/SchoolScores.svelte';

describe('SchoolScores Component', () => {
  const baseSchoolData = {
    escola: 'Colégio Estadual do Futuro',
    endereco: 'Av Central, 500',
    co_entidade: '998877',
    nu_ano_censo: '2026',
    data_atualizacao: '2026-01-01T12:00:00Z',
    score_capacidade_atendimento: '2.5', // < 3 -> Vermelho (#ef4444)
    score_infraestrutura: '5.5',         // < 6 -> Amarelo (#eab308)
    score_capacitacao_docente: '7.5',    // < 8 -> Azul (#3b82f6)
    score_diversidade_discente: '9.0',   // >= 8 -> Verde (#22c55e)
  };

  it('deve renderizar os cabeçalhos e metadados da escola corretamente', () => {
    render(SchoolScores, { schoolData: baseSchoolData, averages: null });

    expect(screen.getByText('Colégio Estadual do Futuro')).toBeInTheDocument();
    expect(screen.getByText(/Código: 998877/)).toBeInTheDocument();
    expect(screen.getByText(/Ano: 2026/)).toBeInTheDocument();
  });

  it('deve aplicar as cores corretas nas barras baseado nos ranges das notas', () => {
    const { container } = render(SchoolScores, { schoolData: baseSchoolData, averages: null });

    // Seleciona todas as divs de preenchimento de barra (.bar-fill)
    const bars = container.querySelectorAll('.bar-fill');

    // Nota 2.5 (Vermelho)
    expect(bars[0].style.backgroundColor).toBe('rgb(239, 68, 68)'); // #ef4444 em RGB
    
    // Nota 5.5 (Amarelo)
    expect(bars[1].style.backgroundColor).toBe('rgb(234, 179, 8)');  // #eab308 em RGB
    
    // Nota 7.5 (Azul)
    expect(bars[2].style.backgroundColor).toBe('rgb(59, 130, 246)'); // #3b82f6 em RGB
    
    // Nota 9.0 (Verde)
    expect(bars[3].style.backgroundColor).toBe('rgb(34, 197, 94)');  // #22c55e em RGB
  });

  it('não deve renderizar a seção de médias se o objeto averages for nulo', () => {
    const { container } = render(SchoolScores, { schoolData: baseSchoolData, averages: null });
    const averagesDiv = container.querySelector('.averages');
    expect(averagesDiv).toBeNull();
  });

  it('deve renderizar as médias regionalizadas quando fornecidas', () => {
    const mockAverages = {
      score_capacidade_atendimento: { municipal: 4.2, estadual: 5.1, nacional: 6.0 }
    };

    render(SchoolScores, { schoolData: baseSchoolData, averages: mockAverages });

    expect(screen.getByText('Municipal: 4.2')).toBeInTheDocument();
    expect(screen.getByText('Estadual: 5.1')).toBeInTheDocument();
    expect(screen.getByText('Nacional: 6.0')).toBeInTheDocument();
  });
});

```

---

### Como rodar e manter atualizado

Como você está usando uma branch de feature (`feat/schools/score`), manter esses testes rodando no background enquanto desenvolve vai te poupar muito tempo de debug manual.

Rode o comando na pasta `frontend/map_app`:

```bash
npm run test
# ou se configurado direto pelo vitest:
npx vitest

```

**Dica para a integração na `SearchSchoolPage.svelte**`: Na página mãe, o modal é controlado via `bind:isOpen={showScoreModal}` e reage ao evento customizado `on:viewScores`. Se você for criar um teste de integração completo nela futuramente, basta disparar um clique simulado no componente `SchList` (no botão de ver scores) e verificar se o texto `"Scores da Escola"` aparece na tela.


# Erros e correções

O erro faz total sentido. O seletor genérico `screen.getByPlaceholderText(/nome/i)` falhou porque o formulário renderizado pelo `SearchForm` contém **dois** inputs cujo placeholder bate com a regex `/nome/i`:

1. *"Digite o **nome** da escola..."*
2. *"Digite o **nome** da cidade..."*

Como a Testing Library é rigorosa, se ela encontra mais de um elemento para uma query do tipo `getBy`, ela joga um erro para te alertar.

Além disso, o compilador do Svelte emitiu alguns alertas de **A11y (Acessibilidade)** muito fáceis de corrigir tanto nos seus arquivos do formulário quanto nos modais (vamos passar por eles também).

---

### 1. Corrigindo o Teste de Integração

Para resolver o teste quebrados, vamos ajustar a query para mirar especificamente na label do elemento ou usar uma expressão mais exata no placeholder.

Abra o arquivo **`src/tests/ScoresModalWithIntegration.test.js`** e altere a linha 52 para buscar pela Label (que é a melhor prática de acessibilidade) ou pelo placeholder exato:

**Substitua isso:**

```javascript
const inputNome = screen.getByPlaceholderText(/nome/i) || screen.getByRole("textbox");

```

**Por isso (Usando a Label associada ao input):**

```javascript
const inputNome = screen.getByLabelText(/Nome da Escola/i);

```

*(Se preferir manter o placeholder, use a string exata: `screen.getByPlaceholderText('Digite o nome da escola...')`).*

---

### 2. Resolvendo os Alertas de Acessibilidade (A11y)

O compilador do Svelte avisa sobre pontos de acessibilidade na hora do build/test. Vamos corrigir os dois tipos apontados no log:

#### A. Falha de Controle nos `select` do `SearchSchoolPage.svelte`

O compilador diz que os elementos `<label>` nas linhas 214, 224 e 235 não estão associados explicitamente a um input/select.

Para arrumar, basta adicionar um `id` ao `<select>` e um atributo `for` correspondente na `<label>`:

```html
<div class="filtro-group">
  <label for="filtro-tipo">🏫 Tipo de escola:</label>
  <select id="filtro-tipo" bind:value={filtroTipo}>
    <option value="todos">Todos</option>
    </select>
</div>

```

*Repita o mesmo padrão criando IDs para o filtro de Cidade (`id="filtro-cidade"`) e de Modalidade (`id="filtro-modalidade"`).*

#### B. Divs com evento de click sem tratamento de teclado (`ScoresModal`, `PayrollModal`, `GradesModal`)

O overlay do modal (`<div class="modal-overlay" on:click={handleClose}>`) aceita clique, mas um usuário navegando por teclado (Tab) ficaria preso sem conseguir fechá-lo.

Você resolve isso adicionando um evento de teclado fictício/real ou adicionando a diretiva `role` e `keydown` recomendada pelo Svelte:

```html
<div 
  class="modal-overlay" 
  on:click={handleClose} 
  on:keydown={(e) => e.key === 'Escape' && handleClose()}
  role="button"
  tabindex="0"
>

```

Assim que você salvar o arquivo do teste com o novo seletor `getByLabelText`, o Vitest que já está rodando em background deve passar o teste de integração imediatamente!

Excelente! É muito bom ver você limpando a saída do console. Deixar o build sem *warnings* evita dores de cabeça no futuro e garante que seu app seja acessível.

O compilador do Svelte está reclamando porque as tags `<div>` são elementos **estáticos** (não interativos por padrão). Quando colocamos listeners de clique ou teclado neles, precisamos dizer aos leitores de tela o que aquele elemento "fingirá" ser.

Para eliminar esses 3 avisos de uma vez, precisamos adicionar três atributos específicos do ARIA: `role`, `tabindex` e ajustar o modificador do container interno.

Aqui está a forma correta e sem *warnings* para o seu trecho:

```html
<div 
  class="modal-overlay" 
  on:click={closeModal} 
  on:keydown={(e) => e.key === 'Escape' && closeModal()}
  role="button"
  tabindex="0"
>
  <div 
    class="modal-container" 
    role="document"
    on:click={(e) => e.stopPropagation()}
    on:keydown={(e) => e.stopPropagation()}
  >
    </div>
</div>

```

---

### O que mudou e por que resolveu?

1. **`role="button"` no overlay:** Explica para o leitor de tela que essa `div` age como um botão (resolve o warning 2 e 3).
2. **`tabindex="0"` no overlay:** Permite que usuários navegando apenas pelo teclado (com a tecla `Tab`) consigam alcançar e focar no overlay para fechá-lo (resolve o warning 1).
3. **`role="document"` no container:** Diz ao Svelte que essa caixa interna é apenas uma seção de conteúdo (um documento/diálogo), tirando a obrigatoriedade de tratá-lo como um botão interativo.
4. **Mudança no `stopPropagation`:** O modificador nativo do Svelte `on:click|stopPropagation` em elementos estáticos às vezes confunde o analisador de acessibilidade. Ao passar uma arrow function explícita chamando `e.stopPropagation()`, o compilador entende perfeitamente o fluxo e silencia os alertas.

Assim que você salvar essa estrutura, os logs do seu terminal vão rodar limpinhos, focando apenas no sucesso dos testes!
