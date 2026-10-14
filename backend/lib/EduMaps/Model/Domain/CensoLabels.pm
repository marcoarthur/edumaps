package EduMaps::Model::Domain::CensoLabels;
use Mojo::Base 'EduMaps::Model::Base', -signatures;
use Mojo::JSON qw(decode_json);
use utf8;

# Rótulos canônicos do Censo Escolar, lidos do dicionário
# (`clean.censo_data_dictionary.value_domain`, issue #134).
#
# Motivo (issue #228): os mesmos rótulos (`1 => 'Federal'`, `1 => 'Urbana'`)
# estavam reescritos à mão em várias roles — Overview, Profile, SchoolNetwork —
# e num `CASE` SQL em Searching. Conhecimento repetido que podia divergir. Aqui
# passa a haver uma fonte só: o domínio oficial do INEP, já curado no dicionário.
#
# O dicionário é dado de referência — só muda com uma migration. Logo o domínio
# é lido uma vez por processo e reusado (cache de classe, `%DOMAIN`). Os testes
# que precisarem de um estado limpo chamam `reset_cache`.
#
# Uso:
#   my $labels = EduMaps::Model::Domain::CensoLabels->new(schema => $c->schema);
#   $labels->rede_label(3);            # 'Municipal'
#   $labels->rede_label_for_slug('municipal');  # 'Municipal'
#   $labels->localizacao_label(1);     # 'Urbana'

has rs => sub { 'CensoDataDictionary' };

my %DOMAIN;   # "$table.$column" => { code => label }

=head2 domain($table, $column)

Hashref C<{ code => label }> com o domínio de valores de uma coluna, ou C<undef>
se o dicionário não tiver a coluna (ex.: coluna numérica, sem enum).

Usa a linha vigente — a de maior C<year_introduced> que não esteja em
C<year_deprecated>.

=cut

sub domain($self, $table, $column) {
  my $key = "$table.$column";
  return $DOMAIN{$key} if exists $DOMAIN{$key};

  my $row = $self->dbic->search(
    { table_name => $table, column_name => $column, year_deprecated => undef },
    { order_by => { -desc => 'year_introduced' }, rows => 1 },
  )->first;

  my $vd;
  if ($row && defined $row->value_domain) {
    my $raw = $row->value_domain;
    $vd = ref $raw ? $raw : decode_json($raw);
  }

  return $DOMAIN{$key} = $vd;
}

=head2 label($table, $column, $code)

Rótulo de um código, ou C<undef> se o código for nulo/desconhecido.

=cut

sub label($self, $table, $column, $code) {
  return undef unless defined $code;
  my $d = $self->domain($table, $column) or return undef;
  return $d->{$code};
}

=head2 rede_label($code)

Rótulo da rede (dependência administrativa): 1..4 -> Federal/Estadual/Municipal/Privada.

=cut

sub rede_label($self, $code) {
  return $self->label('clean.censo_escolas', 'tp_dependencia', $code);
}

=head2 localizacao_label($code)

Rótulo da localização: 1 -> Urbana, 2 -> Rural.

=cut

sub localizacao_label($self, $code) {
  return $self->label('clean.censo_escolas', 'tp_localizacao', $code);
}

# Vocabulário de slug da API (entrada) -> código do Censo. Diferente dos
# rótulos: o slug é contrato de API e vive aqui, uma vez só, em vez de ser
# reescrito em cada role que filtra por rede.
our %REDE_SLUG = (
  federal   => 1,
  estadual  => 2,
  municipal => 3,
  privada   => 4,
);

=head2 rede_code($slug)

Código do Censo a partir do slug da API (federal|estadual|municipal|privada),
case-insensitive. C<undef> para slug inválido.

=cut

sub rede_code($self, $slug) {
  return undef unless defined $slug;
  return $REDE_SLUG{lc $slug};
}

=head2 rede_label_for_slug($slug)

Rótulo do Censo a partir do slug da API — junta o vocabulário de slug ao
domínio canônico.

=cut

sub rede_label_for_slug($self, $slug) {
  my $code = $self->rede_code($slug);
  return undef unless defined $code;
  return $self->rede_label($code);
}

=head2 sql_case($expr, $table, $column, %opts)

Uma expressão SQL C<CASE $expr WHEN <código> THEN '<rótulo>' ... END>, montada a
partir do domínio canônico — para que os rótulos não voltem a ser reescritos
dentro de uma query.

C<%opts> aceita C<else> (expressão SQL de fallback, ex.: C<q{'Não informado'}>).
Se o domínio não existir, devolve o C<else> ou C<NULL::text>.

=cut

sub sql_case($self, $expr, $table, $column, %opts) {
  my $d = $self->domain($table, $column);
  return $opts{else} // 'NULL::text' unless $d && %$d;

  my $when = join ' ', map {
    my $label = $d->{$_};
    $label =~ s/'/''/g;
    sprintf "WHEN %s THEN '%s'", $_, $label;
  } sort { $a <=> $b } keys %$d;

  my $else = exists $opts{else} ? " ELSE $opts{else}" : '';

  return "CASE $expr $when$else END";
}

=head2 reset_cache

Limpa o cache de classe. Só para testes.

=cut

sub reset_cache { %DOMAIN = () }

1;
