Para criar uma família de modelos estatísticos em Perl, o padrão mais adequado é o **Template Method** combinado com **Factory Method**. O **Template Method** define o esqueleto de um algoritmo na classe base (ex: `fit`, `predict`), permitindo que subclasses sobrescrevam etapas específicas. O **Factory Method** fornece um ponto centralizado para instanciar o modelo correto com base em parâmetros (ex: tipo de modelo, hiperparâmetros).

Além disso, você pode usar **Roles** (com Moo/Moose) para reutilizar comportamentos transversais como serialização, validação de dados, logging, etc.

Vou detalhar uma arquitetura em Perl usando **Moo** (leve, compatível com Mojo::Base) ou **Moose** (mais completo). Como você está no ecossistema Mojo, podemos usar **Moo** sem problemas.

---

## 🧱 Estrutura de Classes

```
Stats::Model               # Classe base abstrata
├── Stats::Model::EDA      # Análise exploratória
│   ├── summary()
│   ├── correlation()
│   └── visualize()
├── Stats::Model::ML::Regression  # Regressão (ML)
│   ├── fit()             # Template method
│   ├── _prepare_data()   # hook
│   ├── _estimate_params() # hook
│   ├── predict()
│   └── evaluate()
├── Stats::Model::ML::Classification  # (futuro)
└── Stats::Model::TimeSeries          # (futuro)
```

---

## 🔧 Exemplo de Implementação com Moo

### 1. Classe Base (`Stats/Model.pm`)

```perl
package Stats::Model;
use Moo;
use Types::Standard qw(ArrayRef HashRef Str Maybe);
use namespace::clean;

# Atributos comuns
has name        => (is => 'ro', isa => Str);
has data        => (is => 'rw', isa => ArrayRef[HashRef]);
has target_col  => (is => 'rw', isa => Maybe[Str]);
has feature_cols => (is => 'rw', isa => ArrayRef[Str]);

# Método abstrato (será sobrescrito)
sub fit {
    my $self = shift;
    die "Method 'fit' must be implemented by subclass";
}

# Método abstrato (será sobrescrito)
sub predict {
    my ($self, $new_data) = @_;
    die "Method 'predict' must be implemented by subclass";
}

# Método concreto (pode ser usado por todas as subclasses)
sub evaluate {
    my ($self, $y_true, $y_pred) = @_;
    # Implementação genérica de métricas (RMSE, MAE, etc.)
    # ...
}

# Método auxiliar para validação de dados
sub _validate_data {
    my ($self) = @_;
    die "No data provided" unless $self->data && @{$self->data};
    # outras validações
}

1;
```

---

### 2. Especialização EDA (`Stats/Model/EDA.pm`)

```perl
package Stats::Model::EDA;
use Moo;
extends 'Stats::Model';

sub summary {
    my $self = shift;
    $self->_validate_data();
    my $data = $self->data;
    # Calcula média, mediana, desvio padrão para cada coluna
    # Retorna um hashref com estatísticas
}

sub correlation {
    my ($self, $col1, $col2) = @_;
    # Calcula correlação de Pearson entre duas colunas
}

sub visualize {
    my ($self, $type, @args) = @_;
    # Gera gráficos (usando GD::Graph, Chart::Gnuplot, etc.)
    # Poderia retornar HTML/PNG para o frontend
}

1;
```

---

### 3. Especialização Regressão (`Stats/Model/ML/Regression.pm`)

```perl
package Stats::Model::ML::Regression;
use Moo;
use namespace::clean;
use Statistics::OLS;  # exemplo
extends 'Stats::Model';

has algorithm => (is => 'ro', default => 'ols');  # ols, ridge, lasso
has params    => (is => 'rw', default => sub { {} });

# Template method - implementa o algoritmo geral
sub fit {
    my $self = shift;
    $self->_validate_data();
    
    # Etapa 1: Preparar dados (feature matrix e target)
    my ($X, $y) = $self->_prepare_data();
    
    # Etapa 2: Estimar parâmetros (hook específico da subclasse)
    my $params = $self->_estimate_params($X, $y);
    
    # Etapa 3: Armazenar parâmetros
    $self->params($params);
    
    return $self;
}

# Hook a ser sobrescrito por algoritmos específicos
sub _estimate_params {
    my ($self, $X, $y) = @_;
    die "Must implement _estimate_params for algorithm $self->{algorithm}";
}

# Implementação concreta para OLS
sub _estimate_params_ols {
    my ($self, $X, $y) = @_;
    # Usa Statistics::OLS ou Math::Matrix
    my $ols = Statistics::OLS->new();
    $ols->setData($X, $y);
    $ols->regress();
    return $ols->coefficients;
}

# Predição
sub predict {
    my ($self, $new_data) = @_;
    my $X = $self->_prepare_features($new_data);
    my $params = $self->params;
    # Calcula predição: y = X * params
    # ...
}

# Métodos auxiliares
sub _prepare_data {
    my $self = shift;
    my $data = $self->data;
    my $target = $self->target_col;
    my $features = $self->feature_cols;
    
    my @X;
    my @y;
    for my $row (@$data) {
        push @y, $row->{$target};
        push @X, [ map { $row->{$_} } @$features ];
    }
    return (\@X, \@y);
}

1;
```

---

### 4. Factory para Criar Modelos (`Stats/Model/Factory.pm`)

```perl
package Stats::Model::Factory;
use Moo;

sub create_model {
    my ($class, $type, %params) = @_;
    
    my $model_class = "Stats::Model::$type";
    
    # Verifica se a classe existe
    eval "require $model_class";
    die "Unknown model type: $type" if $@;
    
    # Instancia e retorna
    return $model_class->new(%params);
}

1;
```

---

### 5. Uso no Controller/Service

```perl
# No seu serviço de análise
use Stats::Model::Factory;

sub analyze_data {
    my ($self, $data, $model_type, $target, $features) = @_;
    
    my $model = Stats::Model::Factory->create_model(
        $model_type,
        data        => $data,
        target_col  => $target,
        feature_cols => $features,
        algorithm   => 'ols',  # para regressão
    );
    
    $model->fit();
    my $predictions = $model->predict($new_data);
    my $metrics = $model->evaluate($expected, $predictions);
    
    return {
        model      => $model,
        predictions => $predictions,
        metrics    => $metrics,
    };
}

# Exemplo de chamada
my $results = analyze_data(
    $student_data,           # arrayref de hashes com notas, faltas, etc.
    'ML::Regression',        # tipo
    'final_grade',           # target
    ['homework_avg', 'attendance', 'midterm_grade']  # features
);
```

---

## 🧩 Padrões Adicionais

### A. Strategy Pattern (para algoritmos intercambiáveis)

Dentro da regressão, você pode ter diferentes algoritmos (OLS, Ridge, Lasso). Use **Strategy** para injetar o algoritmo:

```perl
# Em Stats::Model::ML::Regression
has 'algorithm_strategy' => (is => 'rw');

sub _estimate_params {
    my ($self, $X, $y) = @_;
    return $self->algorithm_strategy->estimate($X, $y);
}

# E então você cria estratégias separadas:
package Stats::Algorithm::OLS;
sub estimate { ... }

package Stats::Algorithm::Ridge;
sub estimate { ... }
```

### B. Builder Pattern (para construir modelos com muitas opções)

Se o modelo tiver muitos hiperparâmetros, use um **Builder**:

```perl
my $model = Stats::Model::Builder->new
    ->type('ML::Regression')
    ->data($data)
    ->target('final_grade')
    ->features(['homework_avg', 'attendance'])
    ->algorithm('ridge')
    ->alpha(0.5)
    ->build();
```

### C. Composite Pattern (para ensembles)

Se você quiser combinar modelos (ex: stacking, bagging), pode usar **Composite**:

```perl
package Stats::Model::Ensemble;
extends 'Stats::Model';
has 'models' => (is => 'ro', default => sub { [] });

sub fit {
    my $self = shift;
    $_->fit for @{$self->models};
}

sub predict {
    my ($self, $data) = @_;
    # Agrega predições de cada modelo
    my @preds = map { $_->predict($data) } @{$self->models};
    # Média ou votação
    return $self->_aggregate(\@preds);
}
```

---

## 🔌 Integração com DBIx::Class e Frontend

No seu backend Edumaps, você pode:

1. Buscar dados via ResultSet e transformar em arrayref de hashes.
2. Chamar o Service que usa o Factory.
3. Retornar resultados (estatísticas, predições) para o frontend em JSON.

Exemplo de endpoint Mojo:

```perl
get '/api/models/regression' => sub {
    my $c = shift;
    
    my $rs = $c->schema->resultset('StudentGrade')->search(
        { year => 2025 },
        { columns => ['homework_avg', 'attendance', 'midterm_grade', 'final_grade'] }
    );
    
    my $data = [$rs->all->map({ +{ %{$_} } })->to_array];  # transforma para hashrefs
    
    my $service = Edumaps::Service::Analysis->new;
    my $result = $service->analyze_data($data, 'ML::Regression', 'final_grade', ['homework_avg', 'attendance', 'midterm_grade']);
    
    $c->render(json => {
        coefficients => $result->{model}->params,
        r_squared    => $result->{metrics}->{r2},
        predictions  => $result->{predictions},
    });
};
```

---

## 📦 Empacotamento e Extensibilidade

Para adicionar um novo modelo (ex: `Stats::Model::TimeSeries::ARIMA`), basta criar uma nova classe que estenda `Stats::Model` e implementar `fit` e `predict`. O Factory automaticamente a descobrirá se você seguir a convenção de nomenclatura.

---

## 🧪 Testabilidade

Cada classe pode ser testada isoladamente. Use mocks para os dados e verifique se os métodos hooks são chamados na ordem correta (Template Method garante isso).

---

## 🏁 Conclusão

O **Template Method** é o padrão central aqui, pois define o fluxo invariante do treinamento e predição, enquanto permite que subclasses forneçam implementações específicas. O **Factory Method** simplifica a criação. **Strategy** e **Builder** são complementos úteis para maior flexibilidade.

Essa arquitetura é **data-centric** porque o foco está nos dados (que vêm do seu banco via DBIx::Class) e nos algoritmos que transformam esses dados em insights. É altamente extensível e mantém o código organizado, seguindo princípios SOLID.

Se precisar de mais detalhes ou exemplos específicos (como implementar regularização ou validação cruzada), é só pedir!

--- 
Essa informação muda o jogo de forma drástica — e **para muito melhor**.

Em arquitetura de sistemas, **dados imutáveis (*Append-Only / Write-Once*) são o verdadeiro "santo graal" da performance**.

Se a base do Censo Escolar/IBGE nunca sofre alterações em anos passados e a entrada do usuário é apenas uma **DSL de Intenção** (uma especificação do tipo: *"Quero rodar uma regressão para o ano 2024, no estado de SP, cruzando a variável X com Y"*), a sua arquitetura ganha 3 superpoderes imediatos:

---

## ⚡ Os 3 Superpoderes da Imutabilidade no EduMaps

### 1. Trafegar Zero Dados entre Perl e R

O Perl nunca precisa carregar linhas do banco ou passar dados em memória para o R. O payload que o Perl recebe do frontend é microscópico ($< 1 \text{ KB}$):

```json
{
  "year": 2024,
  "spatial_scope": { "uf": 35 },
  "model_type": "OLS",
  "target": "taxa_aprovacao",
  "features": ["ratio_aluno_computador", "docentes_com_superior"]
}

```

O Perl valida essa **Intenção**, empacota essa especificação e passa **apenas os parâmetros de consulta** para o R ou DuckDB. O motor estatístico lê a fonte de dados diretamente no disco/banco de forma nativa e ultra-otimizada.

---

### 2. Cache Determinístico Permanente (*Content-Addressable Cache*)

Como a fonte da verdade para o ano de 2023 é imutável, o resultado da combinação `[Ano + Recorte Geográfico + Variáveis + Algoritmo]` será **estritamente idêntico para sempre**.

Você pode gerar um Hash SHA256 da especificação da requisição:


$$\text{Cache Key} = \text{sha256}("2024-UF35-OLS-taxa_aprovacao-ratio_aluno_computador")$$

* **Primeiro usuário que pede essa análise:** O Minion aciona o R, calcula em background e grava no Redis/Postgres.
* **Todos os próximos usuários do mundo:** O Perl lê o resultado no Redis em **$< 2 \text{ ms}$**, sem sequer encostar no R ou no banco de dados do Censo.

---

### 3. Armazenamento em Parquet / DuckDB em vez de RDBMS Rígido

Para dados imutáveis de séries temporais como o Censo Escolar, você não precisa de um banco relacional transacional pesado para a camada analítica.

Você pode organizar os dados do Censo em arquivos **Apache Parquet** particionados por ano e UF no servidor:

```text
/data/censo/
├── year=2023/
│   ├── uf=35.parquet   (São Paulo)
│   └── uf=33.parquet   (Rio de Janeiro)
└── year=2024/
    ├── uf=35.parquet
    └── uf=33.parquet

```

Quando a requisição chega no R ou DuckDB via Perl, ele faz o *query pushdown* lendo **somente as colunas e a partição exata necessária direto do disco em milissegundos**.

---

## 🏗️ Como Fica o Fluxo Refinado da Arquitetura

```
[ Frontend ] ──(1) Envia Intenção JSON ──► [ Perl / Mojolicious ]
                                                  │
                                          (2) Gerar SHA256(Intent)
                                                  │
                                        ┌─────────┴─────────┐
                                  (Hit) │                   │ (Miss)
                                        ▼                   ▼
                                 [ Redis Cache ]     [ Minion Queue ]
                                 (Retorna instantâneo)      │
                                                            │ (3) Repassa a Intenção
                                                            ▼
                                                    [ R Engine / DuckDB ]
                                                            │
                                                            │ (4) Leitura direta em Parquet/DB
                                                            ▼
                                                    [ Data/Censo 2024 ]

```

---

## 🛠️ Exemplo de Implementação Simplificada da "Intenção" em Perl

Agora a sua classe `Stats::Model::Specification` em Perl cuida apenas de validar os parâmetros e calcular a chave única:

```perl
package EduMaps::Model::Specification;
use Moo;
use Digest::SHA qw(sha256_hex);
use Mojo::JSON qw(encode_json);

has year          => (is => 'ro', required => 1);
has spatial_scope => (is => 'ro', required => 1); # ex: { uf => 35 }
has target        => (is => 'ro', required => 1);
has features      => (is => 'ro', required => 1); # arrayref
has algorithm     => (is => 'ro', default => 'ols');

# Gera a chave de cache determinística com base na intenção
sub cache_key ($self) {
    my $normalized = {
        year      => $self->year,
        scope     => $self->spatial_scope,
        target    => $self->target,
        features  => [ sort @{$self->features} ],
        algorithm => $self->algorithm,
    };
    return "analytics:v1:" . sha256_hex(encode_json($normalized));
}

1;

```

E a Task do **Minion** repassa apenas essa especificação para o R rodar uma query direta no arquivo Parquet do ano/estado correspondente:

```r
# No R (usando DuckDB/Arrow para performance absurda em Parquet)
library(duckdb)
library(jsonlite)

run_analysis <- function(intent_json) {
  intent <- fromJSON(intent_json)
  
  # Monta o caminho do arquivo Parquet imutável
  parquet_path <- sprintf("/data/censo/year=%d/uf=%d.parquet", 
                          intent$year, 
                          intent$spatial_scope$uf)
  
  # Executa o cálculo direto sobre o Parquet via SQL em memória RAM vetorial
  con <- dbConnect(duckdb())
  query <- sprintf("SELECT %s, %s FROM read_parquet('%s')", 
                   intent$target, 
                   paste(intent$features, collapse = ", "), 
                   parquet_path)
  
  df <- dbGetQuery(con, query)
  dbDisconnect(con)
  
  # Roda a regressão com o dataframe filtrado
  formula <- as.formula(paste(intent$target, "~ ."))
  fit <- lm(formula, data = df)
  
  return(summary(fit))
}

```

---

## 🎯 Conclusão

Essa premissa de **dados imutáveis + especificação de intenção** simplifica o EduMaps drasticamente:

1. **Escalabilidade Extrema:** $90\%$ das requisições comuns no frontend (ex: dashboards padrões de secretários de educação) baterão no cache e nem tocarão no R.
2. **Baixíssimo Custo de Hardware:** O Perl fica leve como uma pena gerenciando roteamento/cache, e o R entra em ação apenas no *Cache Miss* lendo arquivos binários Parquet compactados.
3. **Sem Locks ou Transações:** Como ninguém edita o passado, você não precisa se preocupar com consistência de banco, *deadlocks* ou concorrência de escrita.

----

## Proxy para R
Excelente observação! Essa arquitetura de **Proxy para R** é uma combinação poderosa: Perl como orquestrador e R como motor computacional. Vou adaptar os padrões anteriores para essa abordagem, mostrando como o Perl se torna uma **fachada (Facade/Proxy)** para o R.

---

## 🏗️ Arquitetura Proposta

```
Stats::Model::R::Base           # Classe base que gerencia conexão com R
├── Stats::Model::R::EDA        # Proxy para funções R (summary, cor, etc.)
├── Stats::Model::R::ML::Regression  # Proxy para lm/glm no R
│   ├── fit()  -> chama lm() no R
│   ├── predict() -> chama predict() no R
│   └── summary() -> chama summary() no R
└── Stats::Model::R::ML::Classification  # Proxy para glm/randomForest
```

---

## 🔧 Implementação com `Statistics::R`

### 1. Classe Base (Gerencia Conexão com R)

```perl
package Stats::Model::R::Base;
use Moo;
use Statistics::R;
use Types::Standard qw(Str ArrayRef HashRef Maybe);
use namespace::clean;

has r => (
    is      => 'lazy',
    builder => sub {
        my $r = Statistics::R->new();
        $r->startR();
        return $r;
    }
);

has data        => (is => 'rw', isa => ArrayRef[HashRef]);
has target_col  => (is => 'rw', isa => Maybe[Str]);
has feature_cols => (is => 'rw', isa => ArrayRef[Str]);

# Métodos auxiliares para transferência de dados
sub _send_data_to_r {
    my ($self, $data, $var_name) = @_;
    $var_name //= 'perl_data';
    
    # Converte dados para formato compatível com R (data.frame via JSON)
    my $json = JSON->new->encode($data);
    my $r = $self->r;
    
    # Cria data.frame no R a partir do JSON
    $r->send(qq{
        library(jsonlite)
        $var_name <- fromJSON('$json')
    });
    
    return $var_name;
}

sub _get_from_r {
    my ($self, $expression) = @_;
    my $r = $self->r;
    $r->send($expression);
    return $r->read();
}

# Métodos abstratos
sub fit {
    my $self = shift;
    die "Must implement fit() in subclass";
}

sub predict {
    my ($self, $new_data) = @_;
    die "Must implement predict() in subclass";
}

sub DESTROY {
    my $self = shift;
    if ($self->{r}) {
        eval { $self->{r}->stopR() };
    }
}

1;
```

---

### 2. Proxy para EDA (Estatísticas Descritivas)

```perl
package Stats::Model::R::EDA;
use Moo;
use JSON;
use namespace::clean;
extends 'Stats::Model::R::Base';

# Sobrescreve para usar funções R
sub summary {
    my $self = shift;
    my $r = $self->r;
    
    # Envia dados para R como data.frame
    my $var_name = $self->_send_data_to_r($self->data);
    
    # Executa summary() no R
    $r->send(qq{
        library(dplyr)
        summary_data <- $var_name %>% summary()
        summary_json <- toJSON(summary_data, auto_unbox = TRUE)
    });
    
    # Recupera o resultado como estrutura Perl
    my $json_result = $r->read('summary_json');
    return JSON->new->decode($json_result);
}

sub correlation_matrix {
    my $self = shift;
    my $r = $self->r;
    
    my $var_name = $self->_send_data_to_r($self->data);
    
    $r->send(qq{
        library(corrplot)
        cor_matrix <- cor($var_name, use = "complete.obs")
        cor_json <- toJSON(cor_matrix)
    });
    
    my $json_result = $r->read('cor_json');
    return JSON->new->decode($json_result);
}

sub visualize {
    my ($self, $type, $output_file) = @_;
    my $r = $self->r;
    
    my $var_name = $self->_send_data_to_r($self->data);
    
    # Gera gráficos usando ggplot2
    $r->send(qq{
        library(ggplot2)
        p <- ggplot($var_name, aes(x = {$self->feature_cols->[0]})) +
             geom_histogram() +
             theme_minimal()
        ggsave('$output_file', p)
    });
    
    return $output_file;
}

1;
```

---

### 3. Proxy para Regressão Linear (com R)

```perl
package Stats::Model::R::ML::Regression;
use Moo;
use JSON;
use namespace::clean;
extends 'Stats::Model::R::Base';

has algorithm => (is => 'ro', default => 'lm');   # lm, glm, ridge, etc.
has formula   => (is => 'rw');                    # Ex: "final_grade ~ homework_avg + attendance"
has model_obj => (is => 'rw');                    # Objeto do modelo R (armazenado)
has coefficients => (is => 'rw');

sub fit {
    my $self = shift;
    my $r = $self->r;
    
    # Prepara dados
    my $data_var = $self->_send_data_to_r($self->data, 'df');
    
    # Constrói fórmula se não fornecida
    unless ($self->formula) {
        my $target = $self->target_col;
        my $features = join(' + ', @{$self->feature_cols});
        $self->formula("$target ~ $features");
    }
    
    # Executa regressão no R
    my $algorithm = $self->algorithm;
    $r->send(qq{
        library(glmnet)  # se for ridge/lasso
        model <- $algorithm($self->formula, data = df)
    });
    
    # Armazena objeto do modelo (como referência no R)
    $self->model_obj('model');
    
    # Extrai coeficientes
    $r->send(qq{
        coef_json <- toJSON(coef(model), auto_unbox = TRUE)
    });
    my $coef_json = $r->read('coef_json');
    $self->coefficients(JSON->new->decode($coef_json));
    
    return $self;
}

sub predict {
    my ($self, $new_data) = @_;
    my $r = $self->r;
    
    # Converte novos dados para R
    my $new_var = $self->_send_data_to_r($new_data, 'new_df');
    
    # Predição
    my $model_var = $self->model_obj;
    $r->send(qq{
        predictions <- predict($model_var, newdata = new_df)
        pred_json <- toJSON(predictions, auto_unbox = TRUE)
    });
    
    my $json_result = $r->read('pred_json');
    return JSON->new->decode($json_result);
}

sub summary {
    my $self = shift;
    my $r = $self->r;
    
    my $model_var = $self->model_obj;
    $r->send(qq{
        summary_obj <- summary($model_var)
        # Converte para lista Perl-friendly
        summary_list <- list(
            r_squared = summary_obj\$r.squared,
            adj_r_squared = summary_obj\$adj.r.squared,
            f_statistic = summary_obj\$fstatistic,
            coefficients = coef(summary_obj)
        )
        summary_json <- toJSON(summary_list, auto_unbox = TRUE)
    });
    
    my $json_result = $r->read('summary_json');
    return JSON->new->decode($json_result);
}

1;
```

---

### 4. Factory Aprimorado (com Registro de Modelos)

```perl
package Stats::Model::R::Factory;
use Moo;
use Module::Find;

# Registro automático de modelos disponíveis
my %model_registry;

sub register_model {
    my ($class, $type, $perl_class) = @_;
    $model_registry{$type} = $perl_class;
}

sub create_model {
    my ($class, $type, %params) = @_;
    
    my $model_class = $model_registry{$type}
        || "Stats::Model::R::$type";
    
    eval "require $model_class";
    die "Unknown model type: $type" if $@;
    
    return $model_class->new(%params);
}

# Registra modelos padrão
__PACKAGE__->register_model('EDA', 'Stats::Model::R::EDA');
__PACKAGE__->register_model('ML::Regression', 'Stats::Model::R::ML::Regression');

1;
```

---

### 5. Serviço de Análise Integrado

```perl
package Edumaps::Service::Analysis;
use Mojo::Base -base;
use Stats::Model::R::Factory;

has 'factory' => sub { 'Stats::Model::R::Factory' };

sub analyze_grades {
    my ($self, $student_data, $model_type, $target, $features) = @_;
    
    # Cria modelo via factory
    my $model = $self->factory->create_model(
        $model_type,
        data        => $student_data,
        target_col  => $target,
        feature_cols => $features,
    );
    
    # Treina (delega para R)
    $model->fit();
    
    # Obtém métricas
    my $summary = $model->summary() if $model->can('summary');
    
    # Predições (se houver novos dados)
    my $predictions = $model->predict($future_data) if $model->can('predict');
    
    return {
        model        => $model,
        summary      => $summary,
        coefficients => $model->coefficients,
        predictions  => $predictions,
    };
}

# Método para EDA rápida
sub exploratory_analysis {
    my ($self, $data) = @_;
    
    my $eda = $self->factory->create_model('EDA', data => $data);
    return {
        summary    => $eda->summary(),
        correlation => $eda->correlation_matrix(),
    };
}

1;
```

---

### 6. Uso no Controller Mojo

```perl
package Edumaps::Controller::Stats;
use Mojo::Base 'Mojolicious::Controller';

sub regression_analysis {
    my $c = shift;
    
    # Busca dados do banco via DBIx::Class
    my $rs = $c->schema->resultset('StudentGrade')->search(
        { year => $c->param('year') },
        { columns => ['homework_avg', 'attendance', 'midterm_grade', 'final_grade'] }
    );
    
    my $data = [$rs->all->map({ +{ %{$_} } })->to_array];
    
    # Executa análise via R
    my $service = Edumaps::Service::Analysis->new;
    my $result = $service->analyze_grades(
        $data,
        'ML::Regression',
        'final_grade',
        ['homework_avg', 'attendance', 'midterm_grade']
    );
    
    # Retorna resultados para frontend
    $c->render(json => {
        status => 'success',
        model => {
            coefficients => $result->{coefficients},
            r_squared    => $result->{summary}->{r_squared},
        },
        analysis => $c->param('return_full') ? $result : undef,
    });
}

sub eda_report {
    my $c = shift;
    
    my $rs = $c->schema->resultset('StudentGrade')->all;
    my $data = [$rs->map({ +{ %{$_} } })->to_array];
    
    my $service = Edumaps::Service::Analysis->new;
    my $eda = $service->exploratory_analysis($data);
    
    $c->render(json => $eda);
}
```

---

### 7. Gerenciamento de Sessão R (Pool de Conexões)

Para evitar criar/terminar R a cada requisição, use um pool:

```perl
package Edumaps::R::Pool;
use Mojo::Base -base;
use Statistics::R;
use Mojo::IOLoop;

has 'size' => 5;
has 'connections' => sub { [] };
has 'queue' => sub { [] };

sub get_connection {
    my $self = shift;
    
    # Tenta pegar uma conexão livre
    for my $conn (@{$self->connections}) {
        unless ($conn->{busy}) {
            $conn->{busy} = 1;
            return $conn->{r};
        }
    }
    
    # Cria nova se houver espaço
    if (@{$self->connections} < $self->size) {
        my $r = Statistics::R->new;
        $r->startR();
        push @{$self->connections}, { r => $r, busy => 1 };
        return $r;
    }
    
    # Fila de espera (assíncrono com Mojo)
    die "No R connections available";
}

sub release_connection {
    my ($self, $r) = @_;
    for my $conn (@{$self->connections}) {
        if ($conn->{r} == $r) {
            $conn->{busy} = 0;
            last;
        }
    }
}

1;
```

E no serviço:

```perl
has 'pool' => sub { Edumaps::R::Pool->new };

sub _with_r {
    my ($self, $callback) = @_;
    my $r = $self->pool->get_connection;
    eval { $callback->($r) };
    $self->pool->release_connection($r);
    die $@ if $@;
}
```

---

## 🎯 Vantagens dessa Arquitetura

| Aspecto | Benefício |
|---------|-----------|
| **Separação de responsabilidades** | Perl lida com lógica de negócio, R com álgebra linear pesada |
| **Reutilização** | Você pode usar qualquer pacote R (glmnet, randomForest, caret) sem reescrever em Perl |
| **Escalabilidade** | Pool de conexões R permite atender múltiplas requisições |
| **Manutenibilidade** | Adicionar um novo modelo é só criar uma nova classe Perl que chama a função R correspondente |
| **Testabilidade** | Pode testar a lógica Perl com mocks sem precisar do R |
| **Performance** | R é otimizado para operações matriciais (BLAS/LAPACK) |

---

## 🧪 Exemplo de Novo Modelo (Random Forest)

```perl
package Stats::Model::R::ML::RandomForest;
use Moo;
extends 'Stats::Model::R::Base';

has 'ntree' => (is => 'ro', default => 500);

sub fit {
    my $self = shift;
    my $r = $self->r;
    
    my $data_var = $self->_send_data_to_r($self->data);
    my $formula = "$self->target_col ~ " . join(' + ', @{$self->feature_cols});
    
    $r->send(qq{
        library(randomForest)
        model <- randomForest($formula, data = $data_var, ntree = $self->ntree)
    });
    
    $self->model_obj('model');
    return $self;
}

sub predict {
    my ($self, $new_data) = @_;
    my $r = $self->r;
    
    my $new_var = $self->_send_data_to_r($new_data);
    $r->send(qq{
        predictions <- predict($self->model_obj, newdata = $new_var)
        pred_json <- toJSON(predictions, auto_unbox = TRUE)
    });
    
    return JSON->new->decode($r->read('pred_json'));
}

1;
```

---

## 📊 Conclusão

Essa abordagem de **Proxy para R** combina o melhor dos dois mundos:

- **Perl**: orquestração, integração com DBIx::Class, lógica de negócio, APIs REST com Mojolicious.
- **R**: poder estatístico, bibliotecas maduras, visualização, modelos de ML.

Os padrões permanecem os mesmos (Template Method, Factory, Strategy), mas a implementação concreta delega o trabalho pesado para o R via `Statistics::R`. O resultado é um sistema flexível, extensível e de alto desempenho para análises data-centric no Edumaps. 🐪📊
