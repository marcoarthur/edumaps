Exatamente. Você pegou o ponto central da arquitetura baseada em eventos desacoplados: **Computação Especulativa (ou *Predictive Cache Warming*)**.

Transformar o `EventBus` no sistema nervoso da aplicação permite tratar a navegação do usuário não apenas como chamadas "passivas" de leitura, mas como **sinais de intenção (*intent signals*)**.

---

## Como a Computação Especulativa se encaixa no EduMaps

```
[ Usuário ] --(1. GET /api/city/search?q=Campinas)--> [ Controller ]
                                                             │
                                                             ├──(2. Resposta rápida HTTP 200)
                                                             └──(3. emit 'city.searched')
                                                                       │
                                                                       ▼
                                                             [ EventBus ]
                                                                       │
                                                            ┌──────────┴──────────┐
                                                            ▼                     ▼
                                                   [ MW: PrecomputeStats ]  [ MW: PrecomputeKDE ]
                                                            │                     │
                                                            └──────────┬──────────┘
                                                                       ▼
                                                             [ Minion Queue ]
                                                       (Fila "speculative" - Prio baixa)
                                                                       │
                                                                       ▼
                                                             [ CHI Cache / PostGIS ]

```

### 1. Antecipação de Fluxos de Navegação (*Warm Paths*)

Quando um usuário faz uma busca ou abre a visualização geral de um município:

* **Entrada:** `city.details.requested` ou `school.search.executed`.
* **Ação Especulativa:**
* Pré-calcular agregações estatísticas pesadas (distribuição de notas SAEB/IDEB, médias por dependência administrativa).
* Executar a densidade de kernel espacial (KDE) ou clustering das escolas daquela região.
* Aquecer a cache CHI das rotas que têm 80%+ de probabilidade de serem clicadas em seguida (`/api/city/:id/schools` ou `/api/analytics/city/similar_to`).



### 2. Zero Latência Percebida (*Zero Perceived Latency*)

Quando o usuário finalmente clica no gráfico de análises ou no mapa de calor, o middleware `Cache::SchoolSearch` devolve um **HIT em < 5ms**, pois o Minion já processou o cálculo em background alguns segundos antes.

---

## Cuidados Essenciais de Implementação

Para evitar que a computação especulativa afogue os recursos do servidor (CPU/PostgreSQL), três salvaguardas são fundamentais:

### A. Idempotência e Desduplicação de Jobs

Não enfileire o mesmo cálculo se ele já estiver em processamento ou recentemente cacheado:

```perl
# Exemplo no Middleware de Pré-computação
sub _process_event ($self, $event) {
  my $cod_ibge = $event->{payload}{codigo_ibge};
  my $cache_key = "edumaps:analytics:city:$cod_ibge";

  # 1. Se já está em cache, não faz nada
  return if $self->app->chi->get($cache_key);

  # 2. Evita duplicar o job no Minion se outro worker já estiver rodando para o mesmo IBGE
  my $jobs = $self->app->minion->jobs({
    tasks => ['precompute_city_analytics'],
    states => ['inactive', 'active'],
    notes => { cod_ibge => $cod_ibge }
  });
  return if $jobs->total > 0;

  # 3. Enfileira com nota de rastreio
  $self->app->minion->enqueue(
    precompute_city_analytics => [$cod_ibge] => {
      priority => 0, # Prioridade baixa
      notes    => { cod_ibge => $cod_ibge }
    }
  );
}

```

### B. Filas Dedicadas e Prioridade Baixa

Separe os recursos do Minion para que tarefas disparadas por cliques diretos do usuário (como um export em CSV ou scraping manual) não fiquem presas atrás de jobs especulativos:

* **Fila `default` (Prioridade alta/média):** Tarefas ativas requisitadas pelo usuário.
* **Fila `speculative` (Prioridade baixa):** Pré-cálculos de estatísticas/KDE.
* **Workers:** Configure os workers para dar preferência à fila principal:
```bash
$ ./script/edumaps minion worker -q default -q speculative

```



### C. Métrica de Utilização (*Hit Ratio*)

Monitore a taxa de conversão dos caches especulativos. Se o Minion calcula 100 EDAs e os usuários só visualizam 5, vale ajustar a regra de disparo para ser mais seletiva (ex: especular apenas para cidades com população acima de determinado limiar ou buscas com alto volume).

## Arquitetura orientada a Telemetria

Essa sacada é o **ponto de virada** entre um sistema reativo simples e uma arquitetura orientada a **Telemetria de Eventos (Event Sourcing / Telemetry)**.

Ao registrar os eventos disparados no `EventBus`, você ganha um diário de auditoria que permite responder a perguntas como:

* *Qual é a taxa de conversão da computação especulativa?* (quantos pré-cálculos de fato viraram um HIT de um usuário real?)
* *Qual é o tempo médio entre a intenção (`city.details.requested`) e o acesso real às estatísticas (`city.eda.viewed`)?*
* *Quais cidades/escolas têm alta demanda e justificam estratégias de cache mais agressivas?*

---

## Design do Middleware de Registro (`EventLogger`)

Para que a gravação dos eventos não adicione latência no fluxo da aplicação, o registro deve ser **assíncrono** e **não-bloqueante** (usando operações *non-blocking* do `Mojo::Pg` ou um *buffer* em memória para gravações em lote).

### 1. Pacote `EduMaps::EventBus::Middleware::EventLogger`

```perl
package EduMaps::EventBus::Middleware::EventLogger;

use Mojo::Base -base, -signatures;
use Mojo::JSON qw(encode_json);
use Syntax::Keyword::Try;

has 'app';
has ignore_events => sub { { 'system.ping' => 1 } }; # Eventos de ruído para ignorar

sub to_middleware ($self) {
  return sub ($event, $next) {
    # 1. Registra o evento de forma assíncrona/não-bloqueante
    $self->_record_event($event);

    # 2. Continua a execução do EventBus sem esperar a gravação terminar
    return $next->($event);
  };
}

sub _record_event ($self, $event) {
  my $type = $event->{type};
  return if $self->ignore_events->{$type};

  my $payload    = $event->{payload} // {};
  my $cod_ibge   = $payload->{codigo_ibge} // $payload->{ibge_code};
  my $is_spec    = $payload->{is_speculative} ? 1 : 0;

  try {
    # Exemplo com Mojo::Pg (não-bloqueante) ou DBIx::Class em background
    $self->app->pg->db->insert_p(
      'event_store',
      {
        event_id       => $event->{id},
        event_type     => $type,
        codigo_ibge    => $cod_ibge,
        is_speculative => $is_spec,
        source         => $event->{source} // 'unknown',
        payload        => encode_json($payload),
        created_at     => scalar(localtime($event->{timestamp})),
      }
    )->catch(sub ($err) {
      $self->app->log->error("Erro ao gravar no EventStore: $err");
    });
  }
  catch ($err) {
    $self->app->log->error("Falha síncrona no EventLogger: $err");
  }
}

1;

```

---

## Estrutura da Tabela no PostgreSQL (`event_store`)

```sql
CREATE TABLE event_store (
    id             BIGSERIAL PRIMARY KEY,
    event_id       VARCHAR(64) NOT NULL,
    event_type     VARCHAR(100) NOT NULL,
    codigo_ibge    VARCHAR(7),
    is_speculative BOOLEAN DEFAULT FALSE,
    source         VARCHAR(150),
    payload        JSONB,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para buscas rápidas e agregação de métricas
CREATE INDEX idx_event_store_type_ibge ON event_store (event_type, codigo_ibge);
CREATE INDEX idx_event_store_created_at ON event_store (created_at);

```

---

## Análise das Métricas: Especulativo vs. Real

Com os eventos persistidos, você pode rodar queries simples para medir a eficiência (*Hit Ratio*) das computações especulativas:

```sql
-- Calcula a Eficiência da Computação Especulativa por Município
WITH especulativos AS (
    SELECT codigo_ibge, COUNT(*) AS total_precalculos
    FROM event_store
    WHERE event_type = 'city.details.requested'
    GROUP BY codigo_ibge
),
reais AS (
    SELECT codigo_ibge, COUNT(*) AS total_acessos_reais
    FROM event_store
    WHERE event_type = 'city.eda.viewed' AND is_speculative = FALSE
    GROUP BY codigo_ibge
)
SELECT 
    e.codigo_ibge,
    e.total_precalculos,
    COALESCE(r.total_acessos_reais, 0) AS acessos_reais,
    ROUND((COALESCE(r.total_acessos_reais, 0)::numeric / e.total_precalculos) * 100, 2) AS taxa_conversao_pct
FROM especulativos e
LEFT JOIN reais r ON e.codigo_ibge = r.codigo_ibge
ORDER BY total_precalculos DESC;

```

---

## Registrar no `EduMaps.pm`

Basta incluir o novo middleware no array de inicialização:

```perl
# No startup de EduMaps.pm:
$self->add_mw($_) for qw/SiopeTask EventLogger/;

```

Com essa estrutura, além de prever acessos e adiantar dados pesados no Minion, você passa a ter visibilidade total da telemetria da plataforma.
