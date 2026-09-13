# User Story: Busca de Escolas Similares (Similarity Search)

**Como** gestor escolar da rede EduMaps,  
**Quero** selecionar um conjunto de indicadores educacionais (ex: Infraestrutura, Capacidade Docente, Nota Média IDEB) e buscar as escolas mais similares à minha instituição dentro de um recorte geográfico (Município, Estado ou País),  
**Para** que eu possa identificar pares de referência, conhecer práticas bem-sucedidas de instituições com perfil semelhante e embasar minhas decisões estratégicas com dados comparativos.

---

## Critérios de Aceitação (Acceptance Criteria)

### 1. Seleção de Indicadores
- O sistema deve exibir um catálogo de indicadores disponíveis (ex: Infraestrutura, Capacidade Docente, Diversidade, IDEB, Taxa de Aprovação, etc.).
- O gestor deve poder selecionar **no mínimo 2 e no máximo 5 indicadores** para compor a "assinatura" da escola.
- Os indicadores selecionados devem ser destacados visualmente.

### 2. Definição do Escopo Geográfico
- O gestor deve poder escolher o universo de comparação entre:
  - **Município** (apenas escolas do mesmo município)
  - **Estado** (apenas escolas do mesmo estado)
  - **País** (todas as escolas do Brasil)
- A opção padrão deve ser **Município**.

### 3. Cálculo de Similaridade
- O sistema deve usar o backend `EduMaps::Model::Role::FindSimilar` com métrica de distância (ex: **Euclidiana** ou **Manhattan**) aplicada aos indicadores selecionados.
- A escola atual (alvo) deve ser excluída dos resultados.
- O cálculo deve considerar apenas escolas que possuem dados para **todos** os indicadores selecionados (tratamento de dados nulos via imputação ou descarte, conforme definido no modelo).

### 4. Exibição dos Resultados
- Exibir uma lista ordenada das **Top 10** escolas mais similares (da menor distância para a maior).
- Cada item da lista deve conter:
  - Nome da escola, município e UF.
  - Os **valores dos indicadores** selecionados (para comparação direta).
  - O **score de similaridade** (ex: 0.95 - quanto mais próximo de 1, mais similar).
- Exibir também o **valor da escola atual** como referência no topo da lista.

### 5. Visualização no Mapa (Opcional, mas desejável)
- As escolas similares devem ser plotadas no mapa principal (Leaflet) com marcadores diferenciados.
- Ao clicar no marcador, deve exibir um popup com as informações da escola e os indicadores.

### 6. Exportação
- O gestor deve poder exportar a lista de escolas similares em formato **PDF** ou **CSV** para compartilhamento com a equipe.

### 7. Performance e Feedback
- O sistema deve exibir um indicador de carregamento durante a busca (já que a consulta pode ser pesada com muitos dados).
- Em caso de erro ou nenhuma escola encontrada, exibir mensagem amigável (ex: "Nenhuma escola similar encontrada no escopo selecionado com os indicadores escolhidos").

---

## Exemplo de Cenários (Gherkin)

### Cenário 1: Busca bem-sucedida no município
**Dado** que estou logado como diretor da "Escola Municipal Dom Pedro II"  
**E** seleciono os indicadores: "Infraestrutura", "Capacidade Docente" e "Nota Média IDEB"  
**E** escolho o escopo "Município"  
**Quando** clico em "Buscar escolas similares"  
**Então** o sistema exibe um loading  
**E** apresenta uma lista com as 10 escolas do mesmo município mais similares à minha  
**E** exibe o valor da minha escola no topo como referência  
**E** os marcadores das escolas são atualizados no mapa

### Cenário 2: Nenhuma escola encontrada
**Dado** que seleciono indicadores com pouca cobertura de dados  
**E** escolho o escopo "Estado"  
**Quando** clico em "Buscar"  
**Então** o sistema exibe a mensagem: "Nenhuma escola encontrada com dados completos para os indicadores selecionados. Tente ampliar o escopo ou selecionar outros indicadores."

### Cenário 3: Exportação de relatório
**Dado** que a lista de similares foi carregada  
**Quando** clico em "Exportar relatório"  
**Então** o sistema gera um PDF com a lista de escolas, seus indicadores e scores de similaridade.

---

## Integração com o Backend (Sugestão Técnica)

- **Endpoint sugerido**: `GET /api/school/:cod_inep/similar`
- **Parâmetros**:
  - `indicators`: lista de IDs dos indicadores (ex: `infraestrutura,capacitacao_docente,ideb_anos_finais`)
  - `scope`: `'municipio'`, `'estado'`, ou `'pais'`
  - `limit`: (padrão 10)
- **Modelo backend**: Utilizar `EduMaps::Model::Role::FindSimilar` de forma dinâmica, construindo o feature vector a partir dos indicadores selecionados (semelhante à lógica de `SchoolQuality`, mas com registro dinâmico de indicadores).

---

## Observações de UX/UI

- A tela de busca de similares pode ser acessada a partir do **Painel do Diretor** ou da **página de detalhes da escola**.
- Para facilitar a vida do usuário, podemos pré-selecionar um conjunto de indicadores "recomendados" (ex: IDEB, Infraestrutura e Taxa de Aprovação), mas deixando a liberdade de escolha.
