Entendo que você está considerando levar o **EventBus** para o backend em Perl (Mojolicious). Isso é uma decisão arquitetural interessante e, quando bem aplicada, traz benefícios significativos. Vamos explorar **quando** e **como** usar um EventBus no backend, com exemplos práticos no seu contexto (Edumaps).

---

## 🧠 O que um EventBus resolve no backend?

No frontend, o EventBus serve para comunicação entre componentes sem acoplamento direto. No backend, o papel é semelhante, mas com nuances:

- **Desacoplamento entre camadas**: separar a lógica de negócio principal (ex: buscar escolas) de efeitos colaterais (ex: auditoria, cache, estatísticas, notificações).
- **Extensibilidade**: permitir que novos módulos reajam a eventos sem modificar o código que os dispara.
- **Observabilidade**: centralizar logs, métricas e tracing.
- **Processamento assíncrono (quando combinado com filas)**: executar tarefas pesadas em background, sem travar a resposta.

---

## 📌 Quando usar um EventBus (vs. chamada direta)

| Situação | Recomendação |
|----------|--------------|
| Ação colateral é **obrigatória** para o funcionamento do sistema (ex: salvar no banco) | **Chamada direta** (síncrona) |
| Ação colateral é **opcional** ou pode falhar sem comprometer a resposta (ex: enviar e-mail, atualizar cache, registrar log) | **EventBus** (assíncrono ou síncrono com tolerância a falhas) |
| Você quer permitir que **plugins/features futuras** reajam a um evento sem tocar no código existente | **EventBus** |
| A ação colateral é **pesada e demorada** (ex: gerar relatório, ML) | **EventBus + fila** (RabbitMQ, Minion) |
| Você precisa de **garantia de entrega** e ordenação | **Fila dedicada** (EventBus puro não garante) |

No seu exemplo:
> `$bus->on('busca-escola', sub { # análises e cacheie se o sistema estiver sob baixa demanda })`

Isso é um caso **clássico** para EventBus:
- A busca em si é a operação principal (síncrona, retorna resultados).
- As análises e o cache são **efeitos colaterais**, podem ser assíncronos e condicionais.

---

## 🛠️ Implementação em Perl com Mojolicious

Vamos construir uma versão minimalista do EventBus, inspirada na sua classe JS, mas adaptada ao ecossistema Perl.

### 1. A classe `EventBus` (singleton)

```perl
package Edumaps::EventBus;
use Mojo::Base -base;
use Scalar::Util qw(weaken);
use Mojo::IOLoop;  # para assincronia, se quiser

has 'handlers' => sub { {} };   # type -> [ coderefs ]
has 'any_handlers' => sub { [] };

# Registra handler para um tipo específico
sub on {
    my ($self, $type, $cb) = @_;
    push @{ $self->handlers->{$type} //= [] }, $cb;
    # Retorna um "unsubscribe" (opcional)
    my $weak_self = $self;  # cuidado com referências circulares
    return sub {
        my @new = grep { $_ != $cb } @{ $weak_self->handlers->{$type} // [] };
        $weak_self->handlers->{$type} = \@new;
    };
}

# Registra handler que recebe todos os eventos
sub on_any {
    my ($self, $cb) = @_;
    push @{ $self->any_handlers }, $cb;
    return sub {
        my @new = grep { $_ != $cb } @{ $self->any_handlers };
        $self->any_handlers(\@new);
    };
}

# Emite um evento (síncrono, mas pode ser assíncrono com Mojo::IOLoop->delay)
sub emit {
    my ($self, $type, $payload) = @_;
    my @handlers = @{ $self->handlers->{$type} // [] };
    my @any = @{ $self->any_handlers };
    
    # Opcional: "source" pode ser obtido via caller ou passado como parâmetro
    # my ($package, $filename, $line) = caller(1);
    # my $source = "$filename:$line";
    
    for my $cb (@handlers, @any) {
        eval { $cb->($payload, { type => $type }) };
        if ($@) {
            warn "[EventBus] Handler falhou para $type: $@";
        }
    }
}

# Versão assíncrona (não bloqueia a resposta)
sub emit_async {
    my ($self, $type, $payload) = @_;
    Mojo::IOLoop->next_tick(sub {
        $self->emit($type, $payload);
    });
}

# Destruir (limpeza)
sub destroy {
    my $self = shift;
    $self->handlers({});
    $self->any_handlers([]);
}

1;
```

### 2. Instância global (acessível em toda a app)

Em Mojolicious, podemos adicionar ao objeto app ou usar um singleton:

```perl
# lib/Edumaps.pm (app)
package Edumaps;
use Mojo::Base 'Mojolicious';
use Edumaps::EventBus;

has 'bus' => sub { Edumaps::EventBus->new };

sub startup {
    my $app = shift;
    
    # Registrar eventos iniciais (opcional)
    $app->bus->on('busca-escola' => sub {
        my ($payload, $meta) = @_;
        # $payload: { query, filters, page, ... }
        # Análises e cache condicional
        $app->log->info("Evento 'busca-escola' recebido: " . $payload->{query});
        # ... ver adiante
    });
    
    # ...
}
```

### 3. Disparando o evento a partir do controller

```perl
package Edumaps::Controller::Schools;
use Mojo::Base 'Mojolicious::Controller';

sub search {
    my $c = shift;
    my $params = $c->req->params->to_hash;
    
    # Busca principal (síncrona)
    my $results = $c->schema->resultset('School')->search_complex($params);
    
    # Dispara evento (assíncrono, para não atrasar a resposta)
    $c->app->bus->emit_async('busca-escola', {
        query     => $params->{q},
        filters   => $params,
        results   => $results,
        user_id   => $c->session('user_id'),
        timestamp => time,
    });
    
    $c->render(json => $results);
}
```

### 4. Handlers específicos (em módulos separados)

Você pode colocar handlers em arquivos próprios, carregados no `startup` ou sob demanda.

```perl
# lib/Edumaps/Listener/Cache.pm
package Edumaps::Listener::Cache;
use Mojo::Base -base;

sub register {
    my ($class, $app) = @_;
    $app->bus->on('busca-escola' => sub {
        my ($payload) = @_;
        my $cache = $app->cache;
        # Só cacheia se a demanda estiver baixa (ex: horário noturno)
        my $hour = (localtime)[2];
        if ($hour < 6 || $hour > 22) {  # madrugada
            $cache->set("search:" . $payload->{query}, $payload->{results}, 3600);
            $app->log->debug("Cache atualizado para busca: $payload->{query}");
        }
    });
}
1;
```

```perl
# lib/Edumaps/Listener/Analytics.pm
package Edumaps::Listener::Analytics;
use Mojo::Base -base;

sub register {
    my ($class, $app) = @_;
    $app->bus->on('busca-escola' => sub {
        my ($payload) = @_;
        # Registra estatísticas (ex: em banco de dados ou Elasticsearch)
        $app->schema->resultset('SearchLog')->create({
            query      => $payload->{query},
            user_id    => $payload->{user_id},
            results_count => scalar @{$payload->{results}},
            timestamp  => $payload->{timestamp},
        });
    });
}
1;
```

E no `startup` da app:

```perl
# Carrega listeners
for my $listener (qw(Cache Analytics)) {
    my $class = "Edumaps::Listener::$listener";
    eval "require $class";
    $class->register($app) unless $@;
}
```

---

## 🔄 Vantagens no backend

1. **Plugabilidade**: você pode ativar/desativar funcionalidades (cache, analytics) apenas registrando ou não o listener, sem alterar o controller.
2. **Separação de responsabilidades**: o controller não sabe sobre cache nem analytics – ele apenas dispara o evento.
3. **Condicionalidade**: a lógica de "se o sistema estiver sob baixa demanda" fica dentro do listener, não polui o fluxo principal.
4. **Testabilidade**: você pode testar o controller isoladamente, verificando apenas que o evento foi emitido (mock do bus). E testar cada listener separadamente.
5. **Evolução futura**: se quiser substituir o cache por Redis, ou mudar a forma de analytics, altera apenas o listener, não o controller.

---

## ⚠️ Quando **não** usar

- **Operações críticas** que devem ser executadas com garantia de sucesso (ex: salvar pagamento) – use chamada síncrona com transação.
- **Ordem estrita de execução** – o EventBus não garante ordem; se A precisa ocorrer antes de B, use uma fila ou chamada direta.
- **Alta frequência de eventos** – se você dispara milhares de eventos por segundo, o overhead dos callbacks pode ser significativo; considere uma fila externa (RabbitMQ, Minion) e processamento em lote.

No seu caso, `busca-escola` provavelmente não é tão frequente a ponto de ser problema.

---

## 🧪 Variante: fila com Minion (para tarefas pesadas)

Se as análises forem pesadas (ex: regressão em R), você pode usar **Minion** (job queue do Mojolicious) e disparar um job em vez de um evento síncrono:

```perl
# No controller
$c->minion->enqueue(analyze_search => [$params->{q}, $results]);
```

O listener se torna um worker Minion, processando em background e sem bloquear a resposta. Essa é uma evolução natural do EventBus para tarefas assíncronas.

---

## 🧩 Sobre o `source` no backend

No backend, o conceito de `source` é menos relevante, pois o código é monolítico e o emissor é sempre "o sistema". Mas se você quiser rastrear a origem (ex: qual endpoint disparou), pode usar `caller` ou passar um identificador manualmente:

```perl
# Usando caller para inferir o source
sub emit_with_caller {
    my ($self, $type, $payload) = @_;
    my ($package, $filename, $line, $subroutine) = caller(1);
    my $source = "$subroutine ($filename:$line)";
    $self->emit($type, { %$payload, _source => $source });
}
```

Ou, mais simples, passar o nome do controller/action:

```perl
$bus->emit('busca-escola', { query => $q, source => 'Schools::search' });
```

---

## 🏁 Conclusão para o Edumaps

- **Sim**, um EventBus é desejável para:
  - Cache condicional.
  - Analytics/auditoria.
  - Notificações (ex: quando uma busca não retorna resultados, disparar `TOAST_ADD` via WebSocket).
  - Extensibilidade futura (ex: integração com Elasticsearch, recomendações).
- Comece com uma implementação simples (síncrona ou assíncrona com `Mojo::IOLoop`).
- Se as tarefas ficarem pesadas, migre para Minion sem alterar o código que emite (troca transparente).

A implementação que mostrei é leve e cabe perfeitamente no seu stack Mojolicious + DBIx::Class. Se quiser, posso detalhar mais algum aspecto (ex: como fazer o bus ser injetado nos controllers, ou como testar com Test::MockModule).
