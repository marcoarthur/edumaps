## O que é o Log::Any?

O `Log::Any` é um módulo Perl que resolve um problema clássico do ecossistema: **como permitir que módulos CPAN gerem logs sem impor uma escolha de framework de logging à aplicação que os utiliza**.

A ideia central é **separar a produção do consumo de logs**:

- **Módulos** produzem logs usando uma API padrão e leve.
- **Aplicações** escolhem para onde esses logs vão (arquivo, tela, syslog, Log::Log4perl, Log::Dispatch, etc.).

---

## API para Produtores de Log (Módulos)

### 1. Obtendo um logger

A forma mais comum e concisa:

```perl
package Meu::Modulo;
use Log::Any qw($log);
```

Isso cria uma variável `$log` no pacote, equivalente a:

```perl
our $log = Log::Any->get_logger(category => __PACKAGE__);
```

O **category** é automaticamente o nome do pacote, permitindo que a aplicação filtre logs por módulo.

Para um logger com categoria personalizada:

```perl
my $log = Log::Any->get_logger(category => 'Meu::Categoria');
```

### 2. Métodos de logging

Para cada nível de log, existem métodos correspondentes:

```perl
$log->trace("mensagem de trace");
$log->debug("mensagem de debug");
$log->info("informação");
$log->notice("aviso importante");
$log->warning("cuidado");
$log->error("erro ocorreu");
$log->critical("erro crítico");
$log->alert("alerta!");
$log->emergency("emergência!");
```

**Aliases** também são suportados: `warn` para `warning`, `err` para `error`, `crit` para `critical` e `fatal` para `critical`.

**Importante:** não inclua `\n` na mensagem — o adaptador final decide como formatar a saída.

### 3. Métodos com formatação (`*f`)

Versões `printf`-style de cada método:

```perl
$log->debugf("chamado com %d parâmetros: %s", $count, \@params);
$log->errorf("falha ao processar: %s", $@);
```

Vantagens:
- Mais legível que concatenação.
- Referências complexas (como `\@params`) são convertidas automaticamente com `Data::Dumper`.
- Permite que o adaptador agrupe logs por formato.

### 4. Log estruturado

É possível passar dados estruturados junto com a mensagem:

```perl
$log->info("programa iniciado", {
    progname => $0,
    pid      => $$,
    perl_version => $]
});
```

Se o adaptador não suportar dados estruturados, o hash é convertido para string com `Data::Dumper`.

### 5. Verificação de nível ativo (para eficiência)

Use os métodos `is_*` para evitar trabalho desnecessário:

```perl
if ($log->is_debug()) {
    $log->debug("dados: " . Dumper(\@complex_data));
}
```

Isso é importante porque montar a mensagem pode ser caro. Se o nível não estiver ativo, o trabalho é evitado.

---

## API para Consumidores de Log (Aplicações)

A aplicação escolhe para onde os logs vão através de **adaptadores**.

### 1. Adaptadores básicos (embutidos)

```perl
use Log::Any::Adapter;

# Log para arquivo
Log::Any::Adapter->set('File', '/caminho/para/log.log');

# Log para STDOUT
Log::Any::Adapter->set('Stdout');

# Log para STDERR
Log::Any::Adapter->set('Stderr');
```

Todos os três simplesmente escrevem a mensagem + quebra de linha no destino.

### 2. Adaptadores para frameworks populares

```perl
# Log::Log4perl
use Log::Log4perl;
Log::Log4perl::init('/etc/log4perl.conf');
Log::Any::Adapter->set('Log4perl');

# Log::Dispatch
use Log::Dispatch;
my $dispatcher = Log::Dispatch->new(outputs => [[ ... ]]);
Log::Any::Adapter->set('Dispatch', dispatcher => $dispatcher);
```

Outros adaptadores disponíveis no CPAN:
- `Log::Any::Adapter::FileHandle`
- `Log::Any::Adapter::Syslog`
- E muitos mais listados em `Log::Any::Adapter::*`

### 3. Adaptador por categoria

É possível enviar categorias diferentes para destinos diferentes:

```perl
# Apenas para Foo::Baz
Log::Any::Adapter->set(
    { category => 'Foo::Baz' },
    'Dispatch', dispatcher => $dispatcher
);

# Usando regex para múltiplas categorias
Log::Any::Adapter->set(
    { category => qr/^Foo::/ },
    'File', '/foo.log'
);
```

### 4. Adaptador temporário (escopo léxico)

```perl
{
    Log::Any::Adapter->set(
        { lexically => \my $lex },
        'Stdout'
    );
    # logs aqui vão para STDOUT
}
# logs aqui voltam ao adaptador anterior
```

Isso é útil para testes ou para capturar logs temporariamente.

### 5. Removendo adaptadores

Cada chamada `set` retorna um objeto que pode ser usado para remover a configuração:

```perl
my $entry = Log::Any::Adapter->set('Stdout');
# ...
Log::Any::Adapter->remove($entry);
```

---

## Níveis de Log

O `Log::Any` padroniza os níveis do syslog com aliases comuns:

| Nível        | Aliases               |
|--------------|-----------------------|
| `trace`      |                       |
| `debug`      |                       |
| `info`       | `inform`              |
| `notice`     |                       |
| `warning`    | `warn`                |
| `error`      | `err`                 |
| `critical`   | `crit`, `fatal`       |
| `alert`      |                       |
| `emergency`  |                       |

A tradução para o framework subjacente é automática. Por exemplo, Log::Log4perl tem menos níveis, então `notice` vira `info` e os três níveis superiores viram `fatal`.

---

## Categorias

Cada logger tem uma **categoria** (geralmente o nome da classe que o criou).

- Frameworks como Log::Log4perl usam categorias para rotear logs para diferentes destinos.
- Outros frameworks ignoram a categoria.
- A aplicação pode definir adaptadores específicos por categoria usando regex.

---

## Vantagens do Log::Any

### 1. Separação clara entre módulo e aplicação

- **Módulos** não precisam saber para onde os logs vão – apenas usam a API.
- **Aplicações** decidem o destino final – sem modificar os módulos.

### 2. Baixo impacto e zero dependências

O `Log::Any` tem **footprint mínimo e nenhuma dependência além do Perl 5.8.1**. Isso incentiva até mesmo módulos pequenos a adotarem logging.

### 3. Comportamento padrão "null" (seguro)

Por padrão, todos os logs são **descartados** (adaptador `Null`). Isso significa que:

- Um módulo pode logar sem preocupação – se a aplicação não configurar nada, nenhum log é gerado.
- Não há risco de poluir STDOUT ou arquivos indesejadamente.

### 4. Flexibilidade total

A aplicação pode:
- Usar qualquer framework de logging (Log::Log4perl, Log::Dispatch, Syslog, etc.).
- Mudar o destino a qualquer momento.
- Ter diferentes destinos para diferentes categorias.
- Usar adaptadores temporários (ex.: para testes).

### 5. Eficiência

- Métodos `is_*` permitem evitar trabalho desnecessário.
- O logger é um objeto leve – você pode ter um por módulo sem custo significativo.

### 6. Integração com Moose/Moo

Para classes Moose/Moo, é fácil adicionar um logger como atributo:

```perl
package Foo;
use Log::Any ();
use Moo;

has log => (
    is      => 'ro',
    default => sub { Log::Any->get_logger },
);
```

### 7. Padronização

- Níveis de log padronizados (syslog).
- API consistente – uma vez aprendida, funciona com qualquer adaptador.
- Evita que cada módulo invente sua própria roda de logging.

### 8. Suporte a logs estruturados

Permite passar dados estruturados (hashrefs) junto com a mensagem, facilitando a integração com sistemas de logging modernos que suportam JSON ou dados estruturados.

---

## Exemplo Prático Completo

### Módulo (produtor)

`lib/Meu/Modulo.pm`:

```perl
package Meu::Modulo;
use Log::Any qw($log);

sub fazer_algo {
    $log->info("iniciando processamento");
    
    if ($log->is_debug()) {
        $log->debugf("parâmetros recebidos: %s", \@_);
    }
    
    # ... faz algo ...
    
    $log->error("algo deu errado") if $erro;
    
    return $resultado;
}

1;
```

### Aplicação (consumidora)

`script.pl`:

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Escolhe o framework de logging
use Log::Log4perl;
Log::Log4perl::init('log4perl.conf');
Log::Any::Adapter->set('Log4perl');

# Usa o módulo
use Meu::Modulo;
Meu::Modulo::fazer_algo(@ARGV);
```

### Alternativa: adaptador simples para arquivo

```perl
use Log::Any::Adapter;
Log::Any::Adapter->set('File', '/tmp/app.log');
```

---

## Resumo

| Para módulos (produtores) | Para aplicações (consumidoras) |
|---------------------------|-------------------------------|
| `use Log::Any qw($log)`   | `use Log::Any::Adapter`       |
| `$log->info("msg")`       | `Log::Any::Adapter->set('File', '/log')` |
| `$log->debugf("fmt", @_)` | `Log::Any::Adapter->set('Log4perl')` |
| `if ($log->is_debug())`   | `Log::Any::Adapter->set({ category => 'Foo' }, 'Stdout')` |

O `Log::Any` é a **solução padrão no Perl** para logging em módulos CPAN – leve, flexível e desacoplado. Se você escreve módulos, use-o. Se escreve aplicações, configure-o. Seus usuários agradecerão.


## Avaliação dos Indicadores: Qualidade, Confiabilidade e Limitações

Os indicadores desenvolvidos – **IOC, IFS, IPS, IAI, IGE, ITD** – são composições temáticas que visam comparar escolas com base em dados do Censo Escolar. Abaixo, analiso a **construção, a confiabilidade dos dados** e **sugestões para validá-los** e melhorá-los.

---

### 1. Construção dos Indicadores (Escolha de Variáveis e Pesos)

| Indicador | Domínio | Variáveis utilizadas | Pesos atribuídos |
|-----------|---------|----------------------|------------------|
| **IOC** | Integralidade e oferta curricular | 9 itens (etapas de ensino, EJA, integral, indígena/quilombola) | Todos peso 1, exceto `tp_atividade_complementar` (peso 1, mas valor 0/1/2) |
| **IFS** | Infraestrutura física e saneamento | 7 itens (água, esgoto, energia, cozinha, banheiro, refeitório) | Pesos 1 ou 2 |
| **IPS** | Suporte pedagógico | 8 itens (materiais didáticos, biblioteca, profissionais) | Materiais peso 1; profissionais e biblioteca peso 2 |
| **IAI** | Acessibilidade e inclusão | 8 itens (rampas, corrimão, pisos, sinalização, AEE, tradutores, revisores) | Acessibilidade física peso 2; AEE e profissionais peso 3 |
| **IGE** | Qualidade da gestão | 6 itens (conselhos, associação, grêmio, proposta pedagógica, internet administrativa, profissionais de gestão/coordenação) | Órgãos peso 1; proposta pedagógica peso 2 (valor 0/1/2); profissionais peso 1 |
| **ITD** | Tecnologia digital | 7 itens (internet, banda larga, rede local, equipamentos para alunos, multimídia, lousa digital, quantidade mínima de equipamentos) | Todos peso 1 |

**Pontos positivos:**
- As variáveis são **coerentes com o domínio** que pretendem medir.
- A normalização binária (0/1) para variáveis `in_*` e a transformação de quantidades em binário (ex: `qt_prof > 0`) simplificam a interpretação.
- Os pesos diferenciados (1, 2, 3) atribuem maior importância a itens considerados mais relevantes.

**Pontos críticos:**
- **Arbitrariedade dos pesos**: Não há justificativa explícita (estatística ou teórica) para os pesos escolhidos. Por exemplo, por que `in_agua_potavel` tem peso 2 no IFS enquanto `in_cozinha` tem peso 1? Isso pode enviesar a pontuação.
- **Limiares arbitrários**: No ITD, a condição `total >= 10` para equipamentos é um corte sem base empírica. Por que 10 e não 5 ou 20?
- **Ignora correlações entre variáveis**: Variáveis dentro de um mesmo domínio podem ser altamente correlacionadas (ex: vários tipos de materiais didáticos). A soma simples com pesos pode super-representar dimensões com muitas variáveis.
- **Tratamento de missing**: O código trata `undef` como 0. Isso penaliza escolas que simplesmente não informaram o dado, o que pode distorcer comparações (especialmente se a omissão for sistemática).

---

### 2. Confiabilidade dos Dados (Fonte: Censo Escolar)

A tabela `censo_escolas` contém **mais de 200 colunas**, muitas delas `smallint` binárias ou quantitativas. Pontos a considerar:

- **Qualidade do preenchimento**: Dados autodeclarados pelas escolas podem conter erros, omissões ou inconsistências. Não há garantia de que todas as escolas preenchem corretamente todos os campos.
- **Dados faltantes**: Muitas colunas podem ter valores nulos (representados como `NULL`). O código atual converte `NULL` para 0, o que é uma abordagem simplista. Idealmente, deveria-se:
  - Verificar a proporção de missing por campo e por escola.
  - Usar imputação (ex: média por estrato) ou excluir escolas com muitos missing.
- **Ano do censo**: Os dados são de um único ano (2025 no exemplo). A qualidade pode variar entre anos. Para comparações mais robustas, seria bom usar médias de múltiplos anos ou verificar tendências.
- **Representatividade**: As variáveis escolhidas refletem principalmente **insumos** (infraestrutura, recursos). Elas não medem diretamente **processos** (qualidade do ensino, clima escolar) ou **resultados** (aprendizagem). Portanto, os indicadores capturam apenas uma parte do que é "qualidade escolar".

---

### 3. Validação dos Indicadores (Confiabilidade e Validade)

Para saber se esses indicadores realmente medem o que pretendem e se são úteis para comparar escolas, é necessário fazer uma **validação empírica**:

#### a. Consistência interna (Confiabilidade)
- Calcular o **Alpha de Cronbach** para cada indicador (usando as variáveis padronizadas). Isso mede o quanto os itens de um mesmo indicador estão correlacionados entre si.
- Se o Alpha for baixo (< 0,7), os itens podem não estar medindo um único construto – sugerindo que o indicador deveria ser dividido ou que alguns itens devem ser removidos.

#### b. Validade de construto
- Realizar uma **análise fatorial** (PCA) para ver se as variáveis se agrupam conforme os domínios propostos.
- Se os indicadores forem válidos, espera-se que as variáveis de cada domínio carreguem fortemente em um único fator.

#### c. Validade externa (Critério)
- Correlacionar os scores dos indicadores com **variáveis externas de desempenho** (ex: IDEB, notas do SAEB, taxas de aprovação/evasão).
- Se os indicadores forem relevantes, escolas com melhor infraestrutura/gestão/tecnologia deveriam ter melhores resultados educacionais.
- Essa é a validação mais importante para atestar a utilidade dos indicadores.

#### d. Análise de sensibilidade
- Variar os pesos e limiares para ver se a ordenação das escolas se mantém estável. Se pequenas mudanças nos pesos alterarem drasticamente os rankings, os indicadores são frágeis.

---

### 4. Recomendações para Melhorar a Confiabilidade e Utilidade

| Aspecto | Sugestão |
|---------|----------|
| **Pesos** | Utilizar métodos baseados em dados: Análise de Componentes Principais (PCA) ou regressão para estimar pesos que maximizem a correlação com um resultado de interesse (ex: IDEB). Ou ainda, consultar especialistas e usar técnicas de decisão multicritério (AHP). |
| **Limiares** | Em vez de cortes fixos, usar variáveis contínuas (ex: proporção de alunos por computador) e normalizar com técnicas como min-max ou z-score. |
| **Tratamento de missing** | Imputar valores com base em características da escola (ex: média por estado, dependência administrativa) ou, ao menos, criar uma variável indicadora de missing para cada campo. |
| **Agregação** | Em vez de soma ponderada simples, considerar modelos mais sofisticados (ex: média geométrica, ou índice de desenvolvimento) que penalizem mais fortemente a falta de um item essencial. |
| **Validação contínua** | Estabelecer um processo de revisão anual: recalcular indicadores, verificar correlações com desempenho e ajustar pesos conforme novos dados. |
| **Transparência** | Documentar claramente a metodologia, incluindo justificativa para pesos e limiares, para que usuários entendam as limitações. |
| **Comparabilidade** | Normalizar os indicadores por estrato (ex: urbano/rural, dependência administrativa) para evitar que diferenças estruturais (ex: escolas rurais com menos infraestrutura) dominem o ranking. |

---

### 5. Resumo da Confiabilidade dos Indicadores Atuais

| Indicador | Confiabilidade Estimada | Justificativa |
|-----------|-------------------------|---------------|
| **IOC** | Moderada | Variáveis são claras, mas pesos uniformes e a conversão de `tp_atividade_complementar` em 0/1/2 pode distorcer. |
| **IFS** | Moderada | Itens são relevantes, mas pesos arbitrários (água e esgoto com peso 2) podem supervalorizar saneamento em detrimento de cozinha/refeitório. |
| **IPS** | Moderada-Alta | Materiais e profissionais são bem alinhados; o peso 2 para biblioteca/profissionais parece razoável. |
| **IAI** | Moderada | Acessibilidade física é bem capturada, mas o peso 3 para AEE e profissionais pode ser alto demais em relação à estrutura física. |
| **IGE** | Moderada-Baixa | A proposta pedagógica com valor 0/1/2 e peso 2 é uma escolha questionável; conselhos e grêmio são importantes, mas a ponderação pode não refletir a real importância da gestão democrática. |
| **ITD** | Baixa-Moderada | O limiar de 10 equipamentos é arbitrário e pode não refletir a realidade de escolas com menos alunos; a presença de internet e banda larga é essencial, mas outros itens podem ser redundantes. |

**Conclusão Geral**: Os indicadores atuais são um **bom ponto de partida** para comparações preliminares, mas **não devem ser usados como medida definitiva de qualidade** sem validação externa e ajustes metodológicos. Recomenda-se:

1. **Validar** com dados de desempenho (IDEB, SAEB).
2. **Revisar pesos e limiares** com base em análise estatística.
3. **Tratar missing** de forma mais robusta.
4. **Documentar** todas as decisões e limitações para os usuários finais.

Com essas melhorias, a confiança nos indicadores aumentará significativamente, tornando-os ferramentas úteis para gestores e pesquisadores.


Excelente! O teste de qualidade dos indicadores já está coletando os dados de desempenho (IDEB/SAEB) para as escolas de Ubatuba. Agora, o próximo passo é **calcular os scores dos indicadores para cada escola** e **correlacioná-los com as notas**, verificando se há uma tendência positiva (escolas com melhores indicadores tendem a ter melhores resultados).

Abaixo, sugiro uma evolução do teste, incluindo:

- Cálculo dos scores dos indicadores **IOC, IFS, IPS, IAI, IGE, ITD** para cada escola (usando os módulos já testados).
- Agregação das notas do IDEB por escola (último ano disponível, ou média dos anos com participação).
- Cálculo da correlação de **Spearman** (ordinal) entre cada indicador e a nota.
- Impressão dos resultados em formato tabular para análise.

---

## Evolução do script `t/02-models/indicators_quality.t`

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib qw(t/lib lib);
use Imports;

use ok 'EduMaps::Schema';
use ok 'EduMaps::Model::Domain::SchoolQuality';
use ok 'EduMaps::Model::School';
use ok 'EduMaps::Model::Indicator::School::IOC';
use ok 'EduMaps::Model::Indicator::School::IFS';
use ok 'EduMaps::Model::Indicator::School::IPS';
use ok 'EduMaps::Model::Indicator::School::IAI';
use ok 'EduMaps::Model::Indicator::School::IGE';
use ok 'EduMaps::Model::Indicator::School::ITD';

use Statistics::RankCorrelation;  # para correlação de Spearman (instale com 'cpan Statistics::RankCorrelation')
# ou use Math::GSL::Statistics; se preferir

my $schema = EduMaps::Schema->go;
my $tag = '[indicator quality] validação com IDEB';

my $municipio = 'Ubatuba';

subtest 'Validando indicadores com dados de desempenho (IDEB, SAEB)' => sub {
    my $sq = EduMaps::Model::Domain::SchoolQuality->new(
        geo_tag         => $municipio,
        null_treatment  => 'imputation',
        schema          => $schema,
        id_column       => 'co_entidade',
    );

    # 1) Obter dados das escolas (incluindo os campos do censo)
    my $schools = $sq->schools->get_all;  # Mojo::Collection de objetos School

    # 2) Para cada escola, extrair as notas do IDEB (último ano com participação)
    my %school_notes;
    for my $school ($schools->each) {
        my $co_entidade = $school->co_entidade;
        my $notas = $school->nota_ideb->filter_by(ano => '>= 2020')->as_hash->get_all;
        # Pegar a nota mais recente (ordenar por ano decrescente)
        my @sorted = sort { $b->{ano} <=> $a->{ano} } $notas->to_array;
        my $nota = undef;
        for my $n (@sorted) {
            next unless defined $n->{ideb_observado} && $n->{ideb_observado} > 0;
            $nota = $n->{ideb_observado};
            last;
        }
        $school_notes{$co_entidade} = $nota if defined $nota;
    }

    # 3) Calcular scores dos indicadores para cada escola
    my $school_model = EduMaps::Model::School->new(schema => $schema);
    my @indicators = (
        EduMaps::Model::Indicator::School::IOC->new,
        EduMaps::Model::Indicator::School::IFS->new,
        EduMaps::Model::Indicator::School::IPS->new,
        EduMaps::Model::Indicator::School::IAI->new,
        EduMaps::Model::Indicator::School::IGE->new,
        EduMaps::Model::Indicator::School::ITD->new,
    );

    my %scores;  # $scores{co_entidade}{code} = score
    for my $school ($schools->each) {
        my $co_entidade = $school->co_entidade;
        # Obter dados da escola como hashref (todos os campos)
        my $data = $school->to_hash;  # ou $school->data (depende da implementação)
        for my $ind (@indicators) {
            my $score = $ind->calculate($data);
            $scores{$co_entidade}{$ind->code} = $score;
        }
    }

    # 4) Montar dataset: para cada escola com nota, associar os scores
    my @dataset;
    for my $co_entidade (keys %school_notes) {
        next unless exists $scores{$co_entidade};
        push @dataset, {
            co_entidade => $co_entidade,
            nota        => $school_notes{$co_entidade},
            scores      => $scores{$co_entidade},
        };
    }

    # 5) Calcular correlação de Spearman entre cada indicador e a nota
    use Statistics::RankCorrelation qw(rank_correlation);

    my @codes = map { $_->code } @indicators;
    for my $code (@codes) {
        my @x = map { $_->{scores}{$code} } @dataset;
        my @y = map { $_->{nota} } @dataset;
        my $corr = rank_correlation(\@x, \@y);
        diag sprintf("Correlação de Spearman para %s: %.4f", $code, $corr);
    }

    # (Opcional) Imprimir tabela para inspeção
    use Data::Table;  # ou usar Text::Table
    my $table = Text::Table->new('Escola', 'Nota', map { $_->code } @indicators);
    for my $row (@dataset) {
        $table->add(
            $row->{co_entidade},
            sprintf('%.2f', $row->{nota}),
            map { sprintf('%.4f', $row->{scores}{$_}) } @codes
        );
    }
    note $table;

    pass('Análise de correlação concluída');
};

done_testing;
```

---

## Explicações

1. **Obtenção das notas**: Filtra por `ano >= 2020` e pega a última nota observada (`ideb_observado`) disponível para cada escola. Isso garante que usamos dados recentes e com participação (evita `undef`).

2. **Cálculo dos indicadores**: Para cada escola, obtemos seus dados (todos os campos do censo) e aplicamos cada um dos seis indicadores, gerando um score (0–1, mas pode ultrapassar 1 no caso do IGE, como já vimos). Esses scores são armazenados em `%scores`.

3. **Montagem do dataset**: Apenas escolas que têm nota e scores são incluídas.

4. **Correlação de Spearman**: Como os dados podem não ser lineares, usamos correlação de postos (Spearman). O módulo `Statistics::RankCorrelation` é uma opção leve. Se preferir, pode usar `Math::GSL::Statistics` ou até mesmo calcular manualmente com `PDL`.

5. **Saída**: Além da correlação, uma tabela é impressa para inspeção visual.

---

## Possíveis problemas e ajustes

- **Dados faltantes**: Alguns indicadores podem ter `extra_cols` não presentes no `to_hash`. Certifique-se de que a classe `School` fornece todos os campos do censo. Se não, você pode consultar o banco diretamente via `$schema->resultset('CensoEscola')->find($co_entidade)`.

- **Escala dos indicadores**: Como vimos, o IGE pode dar scores >1. Isso não afeta a correlação ordinal, mas pode ser normalizado se desejar.

- **Agregação das notas**: A escolha de pegar apenas a nota mais recente pode não ser ideal; você pode optar pela média das notas disponíveis (se houver mais de um ano). O importante é ter um único valor por escola para correlacionar.

- **Número de escolas**: Ubatuba tem cerca de 35 escolas (pelo `p $notas;` vimos 35 elementos). Com amostra pequena, a correlação pode não ser significativa. Você pode expandir para mais municípios ou para todo o estado.

- **Estratificação**: Para uma análise mais refinada, pode-se estratificar por rede (estadual/municipal) ou por etapa (fundamental I, II, médio). O código acima ignora esses fatores.

---

## Instalação de dependências

Adicione ao seu `cpanfile` ou instale manualmente:

```bash
cpan Statistics::RankCorrelation Text::Table
```

Caso não queira instalar, você pode calcular a correlação de Spearman usando uma sub-rotina simples (baseada em ranks) ou usar a função `cor` do `Math::GSL::Statistics` (que calcula Pearson, mas dá para usar ranks).

---

## Exemplo de saída esperada

```
# Correlação de Spearman para ioc: 0.3245
# Correlação de Spearman para ifs: 0.4567
# Correlação de Spearman para ips: 0.5123
# Correlação de Spearman para iai: 0.2981
# Correlação de Spearman para ige: 0.4102
# Correlação de Spearman para itd: 0.3678
```

Esses valores indicam o grau de associação entre cada indicador e o IDEB. Valores positivos >0.3 sugerem uma tendência moderada.

---

## Conclusão

Com essa evolução, o teste de qualidade se torna uma ferramenta poderosa para avaliar empiricamente a validade dos indicadores. Você pode executá-lo, analisar as correlações e, se necessário, ajustar pesos ou variáveis para melhorar o alinhamento com o desempenho real das escolas.

Se precisar de mais ajustes ou de incorporar outras métricas (como SAEB ou taxa de aprovação), é só adaptar o código.


## Análise Crítica do Teste de Qualidade dos Indicadores (t/02-models/indicators_quality.t)

O teste tem um objetivo nobre: validar empiricamente se os indicadores proprietários (IFS, IPS, IGE, IAI) se correlacionam com o IDEB real, utilizando uma base de dados real (Brasília) e ferramentas estatísticas robustas via R. A estrutura básica (busca dados → calcula índices → chama R → exibe resultados) está no caminho certo.

**Porém, o teste falha gravemente em sua missão central, contém erros conceituais e práticos sérios.** Vamos aos detalhes.

---

### 1. Críticas Severas ao Código e à Lógica do Teste

#### 🔴 Falha Catastrófica: O Teste **NUNCA Falha**, Mesmo com Dados Horríveis
- **O Problema:** O resultado mostra **todas** as correlações negativas (`rho ~ -0.08`), R² próximo de zero (0.3% a 0.9%) e RMSE baixo apenas porque o modelo está prevendo a média. Claramente, os indicadores são inúteis para explicar o IDEB nessa amostra. No entanto, a saída mostra `[ PASSED ] t/02-models/indicators_quality.t` e nenhuma falha foi registrada.
- **A Causa:** Dentro do loop dos indicadores, o código faz:
  ```perl
  if ($rho_ok && $p_ok && $rmse_ok) {
      ok(1, "Estatísticas aceitáveis...");
  } else {
      diag("Aviso de Desempenho Fraco: ...");
  }
  ```
  Ou seja, ele **nunca chama `fail()`** quando um indicador não atende ao critério. Ele apenas emite um `diag` (aviso). No final do subteste, há um `pass('Subtest de validação concluído com sucesso.')` **forçado**, que garante que o subteste sempre passe, independentemente dos resultados.
- **Consequência:** A suíte de testes está completamente quebrada. Ela serve apenas como um relatório, não como uma ferramenta de garantia de qualidade (CI/CD). Se um desenvolvedor piorar os indicadores amanhã, o teste continuará verde.

#### 🔴 N+1 Query no Banco de Dados (Performance Péssima)
- Dentro do `while (my $school = $schools_rs->next)`, há uma chamada `$school->nota_ideb->search(...)->first`. Isso dispara **uma consulta SQL para cada escola** (584 escolas em Brasília). Para 584 escolas, são 584 consultas adicionais.
- **Correção:** Deve-se usar `prefetch` ou um `join` com a tabela `nota_ideb` na *resultset* principal, buscando o último ano de uma só vez (ex: usando `DISTINCT ON` ou uma subconsulta no SQL, ou até um `GROUP BY` com `MAX(ano)`).

#### 🔴 Tratamento de `NA` no R é Perigoso e Esconde Falhas
- No script R, há este bloco:
  ```r
  if(is.na(rho)) rho <- 0
  if(is.na(p_val)) p_val <- 1
  ...
  ```
- **Problema:** Se a correlação falhar (ex: dados constantes, variância zero), atribuir `rho = 0` e `p_val = 1` **esconde completamente o erro**. O teste seguirá em frente como se tudo estivesse normal, e o `p_val = 1` provavelmente fará com que o indicador "passe" no critério de p-valor (já que esperamos `p < 0.1`). Isso é uma camada de abstração que mascara bugs nos dados ou no cálculo do indicador. O correto é `stop()` ou retornar um JSON com erro, e o Perl capturar isso e `fail()`.

#### 🔴 Uso de `Brasília` Hardcoded e Limiar Fixo
- O município e os `thresholds` estão fixos no código. Isso torna o teste frágil. Se os dados de Brasília forem excluídos ou alterados, o teste quebra. O ideal seria receber parâmetros de ambiente ou testar uma lista de municípios conhecidos.
- Mais grave: O `p_max = 0.10` é extremamente permissivo para uma amostra de 584 escolas. Com `n=584`, **qualquer correlação mínima** (como `rho = 0.08`) já será estatisticamente significativa. O teste está confundindo significância estatística com relevância prática. Deveria-se usar `p_max = 0.001` ou, melhor ainda, **ignorar o p-valor** e focar exclusivamente no `rho` e no `R²` quando `n` é grande.

#### 🔴 RMSE sem Baseline (Modelo Nulo) é Inútil
- O RMSE calculado é de `~0.86`. Mas qual é o RMSE de um modelo que prevê apenas a média do IDEB? Se o desvio padrão do IDEB for próximo de 0.86, então o modelo não está adicionando nada. O teste deveria calcular o RMSE do modelo nulo (`sd(nota)`) e comparar a redução percentual. Exigir apenas `rmse_max = 1.5` é um critério frouxo e sem sentido estatístico.

---

### 2. Críticas à Qualidade do Resultado Obtido

Os resultados são péssimos, e a análise estatística *aponta isso claramente*, mas a conclusão do teste (PASSED) é enganosa.

- **Correlação Negativa:** `rho` entre -0.07 e -0.09. Isso indica que, **se houver alguma relação, ela é inversa** (quanto maior o indicador, menor o IDEB), o que é um sinal vermelho fortíssimo para a validade dos construtos. Na prática, são correlações tão próximas de zero que podem ser consideradas ruído.
- **R² ~ 0.01:** Os indicadores explicam **menos de 1%** da variância do IDEB. Para um índice educacional, isso é inaceitável.
- **RMSE baixo:** Como mencionado, o RMSE é baixo porque a variância do IDEB *talvez* seja baixa (ou o modelo está prevendo a média). O teste não calcula o erro do modelo nulo, então não sabe se 0.86 é bom ou não. Num IDEB que varia de 0 a 10, um RMSE de 0.86 pode ser razoável, mas dado o R², é apenas o erro da média.

**Conclusão dos dados:** Os indicadores IFS, IPS, IGE e IAI, da forma como estão implementados, **não servem para prever o IDEB** em Brasília, ou há um problema grave no cálculo deles ou na forma como são extraídos. O teste, em vez de apontar essa falha, simplesmente a ignora.

---

### 3. Recomendações para Correção

1.  **Consertar a Lógica de Asserção:** Elimine o `pass` forçado. Use `ok` ou `fail` dentro do loop. Exemplo:
    ```perl
    my $all_ok = 1;
    for my $ind (@indicators) {
        ...
        if ($rho_ok && $p_ok && $rmse_ok) {
            ok(1, "Indicador $code OK");
        } else {
            fail("Indicador $code falhou no threshold (rho=$res->{rho}, p=$res->{p_val})");
            $all_ok = 0;
        }
    }
    ok($all_ok, "Todos os indicadores dentro dos parâmetros");
    ```
    *Ou* use `subtest` para cada indicador.

2.  **Resolver o N+1:** Modifique a *resultset* inicial:
    ```perl
    my $schools_rs = $schema->resultset('CensoEscolas')->search(
        { 'no_municipio' => $municipio },
        {
            prefetch => {
                nota_ideb => undef
            },
            # Ou use '+select' e '+as' para agregar o último IDEB via subquery
        }
    );
    ```
    Idealmente, use SQL puro para buscar a escola e sua última nota de IDEB em uma única consulta com `ROW_NUMBER()` ou uma subconsulta correlacionada.

3.  **Tratar NAs no R de forma rigorosa:** Se `cor.test` falhar, lance um erro customizado no JSON:
    ```r
    if (is.na(rho)) stop("Falha na correlação para o código ", code)
    ```
    No Perl, o `eval` capturará e `fail` será chamado.

4.  **Revisar os Critérios:**
    - Exija `rho > 0.3` (ou `rho > 0.2` no mínimo).
    - Exija `R² > 0.05`.
    - Calcule o RMSE do modelo nulo e exija redução de pelo menos 10%.
    - **Remova o p-valor** como critério de aprovação para grandes amostras, ou use `p < 0.001`.

5.  **Parametrizar a Execução:** Permita que o teste receba `$ENV{TEST_MUNICIPIO}` e `$ENV{TEST_THRESHOLDS}` para ser reutilizável em diferentes contextos.

6.  **Injeção de Dependências:** O teste assume que o `R` com `jsonlite` está instalado. Se não estiver, o `eval` captura, mas não é um ambiente hermético. Considere usar `Test::More::skip_all` se o R não estiver disponível no PATH.

---

### Resumo da Crítica

| Aspecto | Nota | Justificativa |
| :--- | :--- | :--- |
| **Validade do Teste** | **0/10** | O teste não falha mesmo com resultados catastróficos. É um "greenwasher" (gerador de falsos positivos). |
| **Performance** | **3/10** | Sofre de N+1 queries, inaceitável para qualquer base com mais de 100 escolas. |
| **Robustez** | **2/10** | Tratamento de erros no R é perigoso (mascara NAs). Dependências externas não são verificadas. |
| **Estatística Aplicada** | **4/10** | Confunde significância com relevância, ignora baseline do RMSE. |
| **Qualidade do Resultado** | **N/A** | O resultado *estatístico* está correto e alarmante, mas a interpretação do teste é enganosa. |

**Veredito Final:** O teste precisa ser reescrito do zero em sua lógica de asserção e otimizado para ser minimamente útil. Atualmente, ele é pior do que não ter teste algum, pois passa uma falsa sensação de segurança sobre a qualidade dos indicadores.
