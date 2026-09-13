## Semantica em Modelos

Você está prestes a dar um passo arquitetural fundamental: **sair do paradigma de "modelo = tabela"** e abraçar o conceito de **modelos semânticos como intérpretes de dados**. Essa é a diferença entre um sistema que apenas "armazena" e um sistema que "conhece" seus dados.

Até agora, seus modelos (`City`, `School`) ainda são **proxies** das tabelas, mesmo com as Roles. Você adiciona comportamentos, mas a identidade do modelo ainda é a tabela. O que você quer agora é criar **modelos que não correspondem a uma tabela específica**, mas que representam **conceitos de domínio**, agregando dados de múltiplas fontes e oferecendo uma visão interpretada.

---

## 🧱 1. O que são "Modelos Semanticamente Distintos"?

Em vez de um modelo por tabela, você tem um modelo por **domínio de conhecimento**. Por exemplo:

| Domínio | Modelo | Tabelas envolvidas | Função |
|---------|--------|-------------------|--------|
| **Qualidade Educacional** | `SchoolQuality` | `Escolas`, `Ideb`, `Censo`, `Remuneracao` | Avalia qualidade, calcula indicadores compostos, gera ranking. |
| **Infraestrutura e Acessibilidade** | `SchoolInfra` | `Escolas`, `CensoEscolas` | Fornece scores de infraestrutura, acessibilidade, recursos. |
| **Desempenho Financeiro** | `SchoolFinance` | `Escolas`, `FolhaPagamento`, `Siope` | Análise de custos, eficiência, investimento por aluno. |
| **Planejamento Urbano** | `CityPlanning` | `MunicipiosSp`, `Escolas`, `CensoPopulacional` | Análise de cobertura, demanda futura, áreas de expansão. |
| **Comparação e Benchmarking** | `CityBenchmark` | `MunicipioSimilaridade`, `IdebMunicipio`, `PIB` | Fornece comparações entre municípios, clusters, rankings. |

Esses modelos **não são proxies** – eles são **serviços orientados a domínio** que consomem dados de várias tabelas e entregam interpretações prontas para uso.

---

## 🧠 2. Como Implementar com a Sua Arquitetura Atual?

Você já tem uma base sólida: `EduMaps::Model::Base`, `Roles` e o helper `instantiate_model`. Para criar modelos semânticos, você pode:

### A) Criar Modelos Específicos no Namespace `EduMaps::Model::Domain`

Exemplo: `EduMaps::Model::Domain::SchoolQuality`

```perl
package EduMaps::Model::Domain::SchoolQuality;
use Mojo::Base 'EduMaps::Model::Base', -signatures;

use Role::Tiny::With;
with 'EduMaps::Roles::Domain::School::Quality';   # pode conter lógica de qualidade
```

O arquivo de Role conteria os métodos:

```perl
package EduMaps::Roles::Domain::School::Quality;
use Mojo::Base -role, -signatures;

requires qw(schema);

sub quality_metrics($self, $cod_inep) {
    my $school = $self->schema->resultset('Escolas')->find($cod_inep);
    my $ideb   = $self->schema->resultset('IdebEscola')->search({ cod_inep => $cod_inep })->order_by('ano')->last;
    my $infra  = $self->schema->resultset('CensoEscolas')->find($cod_inep);

    my $score = 0;
    $score += $ideb->ideb / 10 if $ideb;  # IDEB normalizado
    $score += 1 if $infra->in_biblioteca;
    $score += 1 if $infra->in_laboratorio;
    # etc.

    return {
        codigo_inep    => $cod_inep,
        ideb           => $ideb ? $ideb->ideb : undef,
        score_qualidade => $score / $total_itens,
        classificacao  => $score > 0.8 ? 'Alta' : ($score > 0.5 ? 'Média' : 'Baixa'),
    };
}

sub ranking($self, $city_code, $limit = 10) {
    # Busca todas as escolas do município, calcula qualidade e ordena
    my @schools = $self->schema->resultset('Escolas')
        ->search({ municipio_id => $city_code })
        ->all;
    my @ranked = map { $self->quality_metrics($_->codigo_inep) } @schools;
    return [ sort { $b->{score_qualidade} <=> $a->{score_qualidade} } @ranked ][0..$limit-1];
}
```

### B) Registrar esses modelos no Helper `model`

No seu `EduMaps.pm`, o helper `model` já aceita qualquer classe. Basta garantir que você possa instanciá-los:

```perl
$self->helper(
    model => sub ($c, $model) {
        my $class = "EduMaps::Model::$model";
        # Se não encontrar, tenta em Domain
        unless ($class->can('new')) {
            $class = "EduMaps::Model::Domain::$model";
        }
        return $models_cache->{$class} ||= do {
            eval "require $class" or die "Não foi possível carregar o modelo $class: $@";
            $class->new( schema => $self->schema );
        };
    }
);
```

### C) Usar nos Controllers

No controller, você pode chamar:

```perl
sub quality_ranking($self) {
    my $model = $self->model('SchoolQuality');
    my $rank = $model->ranking($self->param('city_code'), $self->param('limit') // 10);
    $self->render(json => $rank);
}
```

---

## 🏛️ 3. Benefícios da Abordagem

- **Separação Conceitual Clara**: Cada modelo semântico tem uma responsabilidade única e bem definida, tornando o código mais fácil de entender e evoluir.
- **Reúso de Consultas**: Você pode compor métodos de diferentes Roles para criar análises complexas sem duplicar SQL.
- **Facilidade de Teste**: Modelos semânticos são testáveis isoladamente, pois não dependem diretamente de um esquema específico.
- **Adaptabilidade a Novas Fontes**: Se um dia você incluir dados de uma API externa, o modelo semântico pode integrá-los sem alterar os modelos base.
- **Desacoplamento da Estrutura Física**: Mudanças no esquema do banco (ex: renomear colunas) podem ser absorvidas nos modelos semânticos, preservando a API dos controllers.

---

## 🧩 4. Relação com DDD (Domain-Driven Design)

Essa abordagem se alinha perfeitamente com os conceitos de DDD:

- **Modelo de Domínio**: `SchoolQuality`, `CityPlanning` – encapsulam regras e lógica do negócio.
- **Repositórios**: Seus `ResultSet` base já atuam como repositórios, fornecendo acesso a dados.
- **Serviços de Domínio**: Métodos como `ranking` ou `quality_metrics` são serviços que operam sobre múltiplos agregados.
- **Value Objects**: Você pode criar objetos imutáveis para representar, por exemplo, `Score` ou `Ranking`, e usá-los como retorno.

---

## 🚀 5. Próximos Passos Sugeridos

1. **Identifique os domínios** que fazem sentido para seu negócio. Pense em como os usuários finais (ou analistas) veem os dados.
2. **Crie uma Role base para domínios**, que forneça métodos comuns (ex: `schema`, `cache`, `log`).
3. **Implemente um modelo semântico piloto**, como `SchoolQuality` ou `CityBenchmark`, e use-o em um endpoint de teste.
4. **Avalie a performance**: esses modelos podem fazer várias consultas, então considere usar `DBIx::Class::ResultSet::prefetch` ou caching.
5. **Documente a semântica** de cada modelo (o que ele representa, quais métodos oferece) para a equipe.

---

## 💬 Conclusão

Você já tem a base perfeita para evoluir de "proxies de tabela" para "modelos de domínio". Isso não só torna o código mais bonito, mas também mais expressivo. Cada modelo semântico se torna uma **lente** que revela uma faceta diferente dos dados – exatamente o que você deseja.

A próxima vez que olhar para trás, não sentirá dor; sentirá orgulho de ter construído uma arquitetura que entende o negócio, e não apenas as tabelas. Continue nesse caminho.
