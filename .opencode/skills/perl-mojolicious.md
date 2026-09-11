# Skill: perl-mojolicious

## Purpose
Auxiliar no desenvolvimento backend Perl/Mojolicious/DBIx::Class no projeto EduMaps.

## Stack do projeto
- Perl 5.42+ (Mojolicious 9.x, DBIx::Class, DBD::Pg)
- Conexão DB: `edu_maps.conf` (não versionado), `EduMaps::Schema->go`

## Padrões do projeto

### ResultSets
```perl
# ResultSet herda de Base (compõe SearchHelpers, Geo, Aggregates, etc.)
my $rs = $schema->resultset('CensoEscolas');

# Padrão de retorno: hashrefs via HashRefInflator
$rs->search_rs($search, { join => 'municipio' })
  ->columns([qw/me.col1 me.col2/, { alias => { sum => 't.col', -as => 'alias' } }])
  ->group_by([qw/me.col1 me.col2/])
  ->as_hash->get_all   # retorna Mojo::Collection de hashrefs
  ->each(sub { $_->{alias} });

# NÃO usar ->all (retorna row objects) + ->get_column em hashrefs
# NÃO usar ->rows(...) (não existe) → usar ->limit(...)
```

### Controllers
```perl
# Objetos Perl → render(json => $hashref)
$self->render(json => $result);

# GeoJSON strings (do postgres) → render(text => ..., format => 'json')
$self->render(text => $geojson_string, format => 'json');

# Validação de rota: código IBGE inválido retorna 404 (não 400)
# Validação de query params inválidos retorna 400
```

### Roles
```perl
package MyRole;
use Mojo::Base -role, -signatures;
# Roles compõem o ResultSet via ->with 'MyRole::Name'
```

### Uso de utf8
- `use utf8;` em TODOS os módulos
- Strings do PG com `pg_enable_utf8=1` vêm utf8-flagged
- `Mojo::JSON::decode_json` falha em strings utf8-flagged com chars não-ASCII
- Correção: `use Encode qw(encode); return encode('UTF-8', $str);` no boundary

## Conexão com banco (verificação)
```bash
PGPASSWORD=senhaboa123 psql -h ubatexu.lan -U devel -d edumaps_dev -c "SELECT 1"
```

## Testes
```bash
cd backend
prove -vl t/02-models/ModelName.t       # isolado
prove -vl t/04-api/network/             # API inteira
yath -l t/02-models/SchoolNetwork.t     # runner moderno
```
