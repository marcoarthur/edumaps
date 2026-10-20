package EduMaps::Model::Ivet::Isocrona;
use Mojo::Base 'EduMaps::Model::Base', -signatures;
use Carp qw(croak);
use utf8;

# Leitura de clean.isocrona_escolar (#278/#295, exposta na #296): as
# células H3 da área de influência da escola (15 min a pé, r9; 45 min de
# carro, r7). A conversão célula -> polígono é do FRONTEND (h3-js) — o
# backend só entrega as células com população.
#
# Regras:
# - Snapshot vigente por escola (max(dt_snapshot) — mesma regra da
#   tabela ivet_escola e da view nacional do IVET).
# - Ausência ≠ 0 (#154): populacao_grade NULL chega como undef; o
#   total por faixa também é NULL quando NENHUMA célula tem população
#   (nunca vira 0).

# Última medição vigente da escola, opcionalmente de uma faixa de tempo.
# Devolve arrayref de hashrefs ordenado por (tempo, população desc);
# vazio quando a escola nunca foi extraída (fora da cobertura).
sub por_escola ($self, $co_entidade, $tempo_minutos = undef) {
  croak "por_escola: co_entidade obrigatório" unless defined $co_entidade;

  my $sql = q{
    SELECT i.co_entidade, i.tempo_minutos, i.resolucao_h3, i.grid_id,
           i.populacao_grade, i.engine, i.engine_version,
           i.tileset_build_date, i.dt_snapshot
      FROM clean.isocrona_escolar i
     WHERE i.co_entidade = ?
       AND i.dt_snapshot = (
             SELECT max(i2.dt_snapshot)
               FROM clean.isocrona_escolar i2
              WHERE i2.co_entidade = i.co_entidade
           )
  };
  my @params = (0 + $co_entidade);
  if (defined $tempo_minutos) {
    $sql .= q{ AND i.tempo_minutos = ? };
    push @params, 0 + $tempo_minutos;
  }
  $sql .= q{ ORDER BY i.tempo_minutos, i.populacao_grade DESC NULLS LAST };

  my $dbh = $self->schema->storage->dbh;
  my $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @params);
  return $rows;
}

1;

__END__

=encoding utf8

=head1 NAME

EduMaps::Model::Ivet::Isocrona - Células H3 da área de influência da escola

=head1 DESCRIPTION

Modelo de leitura de C<clean.isocrona_escolar> para o endpoint
C<GET /api/school/:cod_inep/isocrona> (#296, PR2). Entrega as células H3
(grid_id, resolução, população) da isócrona vigente; a conversão
célula→polígono é responsabilidade do frontend (h3-js).

=cut
