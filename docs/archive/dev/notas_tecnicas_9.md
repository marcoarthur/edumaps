## Por que alguns scores estão fora da escala 0–10?

O erro no teste mostra um score de **10,61**, indicando que o valor ultrapassou o limite superior de 10. Embora a lógica do SQL pareça correta (todas as fórmulas foram construídas para resultar em valores entre 0 e 10), a causa mais provável é a **presença de dados inconsistentes nas colunas que deveriam ser binárias (0 ou 1)**.

### 🔍 Origem do problema

No Censo Escolar, colunas com o prefixo `in_` (indicadores) normalmente armazenam apenas `0` ou `1`. Porém, na prática, essas colunas podem conter valores como `2`, `3`, `NULL` ou até números negativos. Quando isso acontece:

- As somas dessas colinas (ex.: `in_agua_potavel + in_energia_rede_publica + ...`) deixam de representar uma contagem de itens verdadeira.
- As médias (`soma / total_de_itens`) passam a ser maiores que 1, elevando o score proporcionalmente.
- No caso do `score_infraestrutura`, por exemplo, se uma categoria tiver 5 itens e cada um estiver com valor `2`, a soma será `10`, a média `2,0` e o termo `2,0 * 10 = 20`. Esse valor de 20, ao ser combinado com outras categorias, pode gerar um score final acima de 10.

### 🧪 Onde o erro se manifesta?

Qualquer score que agregue múltiplos indicadores binários está sujeito à distorção:

- **score_infraestrutura** (categorias A, B, C, D)
- **score_capacidade_atendimento** (soma de `in_comum_*`)
- **score_sustentabilidade** (vários indicadores)
- **score_capacidade_gestora** (soma dos colegiados, que também são indicadores)

O valor `10,61` sugere um desvio pequeno, possivelmente causado por um ou dois indicadores com valor `2` em vez de `1`, ou por um total de colegiados igual a `6` (em vez de `5`).

---

## 🛠️ Como corrigir definitivamente

A solução é **normalizar todas as colunas de indicadores** para `0` ou `1` antes de usá‑las nos cálculos. Use `CASE WHEN COALESCE(coluna, 0) > 0 THEN 1 ELSE 0 END` ou a função `LEAST(COALESCE(coluna, 0), 1)`.

### Exemplo de correção para o `score_infraestrutura`

Substitua cada ocorrência de `COALESCE(in_agua_potavel,0)` por:

```sql
CASE WHEN COALESCE(in_agua_potavel, 0) > 0 THEN 1 ELSE 0 END
```

Ou, de forma mais compacta:

```sql
LEAST(COALESCE(in_agua_potavel, 0), 1)
```

Aplique essa transformação a **todas as colunas `in_*`** usadas nas seguintes partes:

- `score_capacidade_atendimento` – soma de `in_comum_*`
- `score_infraestrutura` – todas as 24 colunas das categorias A, B, C, D
- `score_docente` – não usa indicadores binários (apenas quantitativos), então está seguro.
- `score_diversidade_discente` – usa apenas colunas `qt_*` (contagens), seguro.
- `score_gestao` – uso de `in_orgao_*` nos colegiados e `in_*` para acesso ao cargo.
- `score_sustentabilidade` – todos os indicadores.

### Exemplo prático de correção para os colegiados (no `score_gestao`)

```sql
LEFT JOIN (
    SELECT
        co_entidade,
        nu_ano_censo,
        ( CASE WHEN COALESCE(in_orgao_ass_pais,0) > 0 THEN 1 ELSE 0 END +
          CASE WHEN COALESCE(in_orgao_ass_pais_mestres,0) > 0 THEN 1 ELSE 0 END +
          CASE WHEN COALESCE(in_orgao_conselho_escolar,0) > 0 THEN 1 ELSE 0 END +
          CASE WHEN COALESCE(in_orgao_gremio_estudantil,0) > 0 THEN 1 ELSE 0 END +
          CASE WHEN COALESCE(in_orgao_outros,0) > 0 THEN 1 ELSE 0 END ) AS qt_colegiados
    FROM clean.censo_escolas
    WHERE tp_situacao_funcionamento = 1
) o ...
```

---

## ✅ Verificação adicional

Após aplicar as correções, recrie a materialized view:

```sql
REFRESH MATERIALIZED VIEW clean.mv_escolas_scores;
```

Em seguida, execute uma consulta para identificar eventuais valores fora da faixa:

```sql
SELECT *
FROM clean.mv_escolas_scores
WHERE score_capacidade_atendimento NOT BETWEEN 0 AND 10
   OR score_infraestrutura NOT BETWEEN 0 AND 10
   OR score_capacitacao_docente NOT BETWEEN 0 AND 10
   OR score_diversidade_discente NOT BETWEEN 0 AND 10
   OR score_capacidade_gestora NOT BETWEEN 0 AND 10
   OR score_sustentabilidade NOT BETWEEN 0 AND 10;
```

Se ainda houver registros fora da escala, examine os dados brutos das escolas correspondentes para identificar outras anomalias (ex.: divisão por zero não tratada, ou colunas `qt_*` negativas).

---

## 📌 Resumo

- **Causa**: valores não binários (ex.: 2, 3) em colunas que deveriam ser `0` ou `1`.
- **Solução**: normalizar todos os `in_*` com `CASE WHEN >0 THEN 1 ELSE 0 END`.
- **Impacto**: os scores passarão a respeitar rigorosamente a escala `[0,10]`.

A correção é simples e resolve definitivamente o problema. Se precisar de ajuda para reescrever todo o script com as normalizações, estou à disposição.

# Testando Frontend

Testar o frontend no ecossistema JavaScript e Svelte pode parecer um território intimidador no início, especialmente vindo de um ambiente de testes backend tão robusto e maduro quanto o do Perl (`Test::Mojo` e `Test2`). A boa notícia é que o ferramental moderno de JS evoluiu muito e adota conceitos bem parecidos com o que você já faz.

Para garantir a robustez do **EduMaps** contra dados faltantes (cenário clássico em bases públicas como INEP/IBGE) e problemas de renderização espacial ou de interface, o ideal é dividir a estratégia em **três camadas de testes**.

Aqui está um plano compreensivo e as melhores escolhas de bibliotecas para o seu stack (Svelte + Docker).

---

## 1. O Stack de Testes Recomendado

Para quem está começando e quer ferramentas sólidas, com boa documentação e excelente integração com o Svelte, esta é a combinação padrão da indústria:

| Tipo de Teste | Ferramenta / Biblioteca | O que ela faz? |
| --- | --- | --- |
| **Test Runner & Mocking** | **Vitest** | O substituto moderno do Jest. É extremamente rápido, funciona nativamente com o Vite (que o Svelte usa) e lida com mocks de API facilmente. |
| **Component Testing** | **Svelte Testing Library** | Permite renderizar componentes Svelte isoladamente e testar o comportamento da perspectiva do usuário (ex: "o botão de mapa está na tela?"). |
| **Browser Environment** | **jsdom** ou **happy-dom** | Um ambiente que simula o navegador em memória dentro do Node/Vitest, permitindo que os testes rodem super rápido no terminal. |
| **End-to-End (E2E)** | **Playwright** | Roda testes em navegadores reais (Chromium, Firefox, WebKit). Perfeito para testar fluxos completos e renderização pesada (como mapas e gráficos). |

---

## 2. Plano de Testes para o EduMaps

### Fase 1: Testes de Componentes e Robustez a Dados Faltantes (Vitest + Testing Library)

Aqui é onde você vai testar como seus componentes Svelte reagem quando o backend Perl (ou a API) falha ou envia dados incompletos.

* **O que testar:**
* Se um município não tiver a nota do IDEB, a interface exibe um estado amigável (ex: "Dado não disponível") em vez de quebrar a tela (o famoso `undefined`).
* Se os componentes de tabelas ou cards renderizam corretamente com strings vazias ou coordenadas nulas.


* **Abordagem:** Você alimenta o componente Svelte com propriedades (`props`) capengas ou mocka a resposta da API usando o Vitest, e verifica se o DOM gerado é seguro.

### Fase 2: Testes de Integração e Fluxo do Usuário (Playwright)

Testes que rodam no terminal, mas controlam um navegador real em background. Essencial para aplicações GIS/Mapas onde o `jsdom` (em memória) não consegue renderizar elementos complexos como canvas ou SVG do Leaflet/OpenLayers de forma fiel.

* **O que testar:**
* O usuário seleciona um estado no dropdown $\rightarrow$ as cidades mudam $\rightarrow$ o mapa foca na região correta.
* Simular latência na rede para ver se o "spinner" de carregamento aparece.



---

## 3. Na Prática: Como seriam esses testes?

Para aproximar o conceito do que você já faz no backend, veja exemplos de estrutura estrutural de código de testes para o frontend:

### Exemplo 1: Testando Robustez (Componente Svelte)

Imagine um componente `<SchoolCard />` que recebe dados do INEP. Queremos garantir que ele não quebre se a nota vier nula.

```javascript
// SchoolCard.test.js
import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import SchoolCard from './SchoolCard.svelte';

describe('Componente SchoolCard', () => {
  it('deve renderizar fallback quando a nota do IDEB estiver faltando', () => {
    // Dados simulando uma escola sem nota informada no banco
    const dadosIncompletos = {
      name: "Escola Estadual Ubatuba",
      ideb_score: null // <-- O perigo mora aqui
    };

    render(SchoolCard, { props: { school: dadosIncompletos } });

    // Verifica se a interface tratou o null elegantemente
    expect(screen.getByText('Nota não disponível')).toBeInTheDocument();
    expect(screen.queryByText('NaN')).not.toBeInTheDocument(); 
  });
});

```

### Exemplo 2: Teste E2E de Renderização (Playwright)

Semelhante ao que você faria com o `Test::Mojo` injetando requisições e testando seletores HTML, mas aqui vendo o comportamento visual real.

```javascript
// e2e/mapa.spec.js
import { test, expect } from '@playwright/test';

test('Deve renderizar o mapa e exibir dados ao clicar', async ({ page }) => {
  // Acessa a rota da aplicação (pode ser apontada para o seu container Docker de dev)
  await page.goto('http://localhost:5173/mapa');

  // Garante que o container do mapa (ex: Leaflet) foi iniciado
  const mapa = page.locator('.leaflet-container');
  await expect(mapa).toBeVisible();

  // Força um erro de API interceptando a rota para testar o comportamento da UI
  await page.route('/api/v1/escolas/*', route => route.fulfill({
    status: 500,
    body: JSON.stringify({ error: 'Erro interno no PostGIS' })
  }));

  // Tenta interagir e verifica se o alerta de erro aparece na tela de forma amigável
  await page.click('#btn-carregar-escolas');
  await expect(page.locator('.alert-danger')).toContainText('Erro ao carregar dados espaciais');
});

```

---

## 4. Próximos Passos para Implementação

1. **Instalação**: Se você iniciou o projeto com SvelteKit ou Vite, você pode adicionar o Vitest e o Playwright rodando `npm init playwright@latest` e `npm i -D vitest @testing-library/svelte`.
2. **Integração com Docker**: Como o seu ambiente já está dockerizado via Docker Compose, a execução do Vitest (testes unitários/componentes) roda perfeitamente dentro de qualquer container Node. Para o Playwright (E2E), ele possui uma imagem Docker oficial (`mcr.microsoft.com/playwright`) que já vem com os navegadores e dependências Linux instalados, facilitando rodar tudo no seu pipeline ou localmente sem poluir sua máquina.
3. **Comece Pequeno**: Não tente testar o mapa inteiro no primeiro dia. Comece criando testes de unidade para funções utilitárias de formatação de dados do IBGE/INEP no frontend, passe para componentes simples (como botões e cards de alertas) e depois avance para os fluxos complexos do mapa.
