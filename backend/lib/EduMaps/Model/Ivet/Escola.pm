package EduMaps::Model::Ivet::Escola;
use Mojo::Base 'EduMaps::Model::Base', -signatures;
use Carp qw(croak);
use utf8;

# Leitura de analytics.ivet_escola (#296): o painel do IVET materializado
# pelo job refresh_ivet (task Minion da fila analytics). A tabela guarda
# histórico por dt_snapshot; a API consome SEMPRE o snapshot vigente por
# escola (max(dt_snapshot) — a mesma regra da view nacional do IVET).
#
# Ausência ≠ 0 (#154): ivet/bloco_* NULL chegam como undef no hashref — o
# controller propaga como null no JSON, nunca como 0.

# Colunas devolvidas por latest() — contrato do endpoint GET
# /api/school/:cod_inep/ivet.
use constant COLUNAS => qw/
  co_entidade nu_ano_censo raio_m ivet publicavel
  bloco_a bloco_b bloco_c bloco_d bloco_e bloco_f bloco_g
  formula dataset_version transform_version dt_snapshot calculado_em
/;

# Última medição vigente da escola. Devolve hashref (colunas de COLUNAS,
# com bloco_* promovidos a blocos => { A .. G }) ou undef quando a escola
# nunca foi medida.
sub latest ($self, $co_entidade) {
  croak "latest: co_entidade obrigatório" unless defined $co_entidade;

  my $dbh = $self->schema->storage->dbh;
  my $row = $dbh->selectrow_hashref(
    q{
      SELECT co_entidade, nu_ano_censo, raio_m, ivet, publicavel,
             bloco_a, bloco_b, bloco_c, bloco_d, bloco_e, bloco_f, bloco_g,
             formula, dataset_version, transform_version,
             dt_snapshot, calculado_em
        FROM analytics.ivet_escola
       WHERE co_entidade = ?
       ORDER BY dt_snapshot DESC
       LIMIT 1
    },
    undef,
    0 + $co_entidade
  );
  return unless $row;

  # blocos { A .. G } no formato do card/linguagem do IVET; NULL vira
  # undef (JSON null), não 0.
  my %rotulo = (a => 'A', b => 'B', c => 'C', d => 'D',
                e => 'E', f => 'F', g => 'G');
  $row->{blocos} = {
    map { $rotulo{$_} => $row->{"bloco_$_"} } keys %rotulo
  };
  delete $row->{$_} for grep { /^bloco_/ } keys %$row;

  # DBD::Pg devolve boolean como 1/0; o JSON precisa de true/false.
  $row->{publicavel} = $row->{publicavel} ? Mojo::JSON::true : Mojo::JSON::false;

  return $row;
}

# Data da medição vigente (para o header/meta da API e checagens
# administrativas de desatualização). undef = tabela vazia.
sub ultimo_snapshot ($self) {
  my $dbh = $self->schema->storage->dbh;
  my ($dt) = $dbh->selectrow_array(
    q{SELECT max(dt_snapshot) FROM analytics.ivet_escola}
  );
  return $dt;
}

1;
