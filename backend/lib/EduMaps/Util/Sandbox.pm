package EduMaps::Util::Sandbox;
use Mojo::Base -signatures;
use Mojo::Collection qw(c);
use EduMaps::Schema;
use Test::Mojo;
use Carp qw(croak);
use Mojo::Util qw(tablify);
use Mojo::JSON qw(encode_json);
use Exporter 'import';
use utf8;

our @EXPORT_OK = qw(busca_escola_similar);
my $t = Test::Mojo->new('EduMaps');

sub busca_escola_similar($opts) {
  my $rs        = $opts->{conjunto};
  my $sch       = $rs->result_source->schema;
  my $minion    = $t->app->minion;
  my $features  = $opts->{features};

  # roda R
  say "Total escolas a serem analisadas: " . $rs->count unless $opts->{modo};
  $rs->perform_similarity_job($minion, 'co_entidade', $opts->{modo});

  # encontra escola com nome parcial
  my $escola = $rs->columns([@$features, 'no_entidade', 'latitude', 'longitude'])
  ->filter_by(no_entidade => {-ilike => "%$opts->{entidade}%"})->first;

  croak qq/Não encontrei escola com busca "$opts->{entidade}"/ unless $escola;

  # encontra similares
  my %topN = $escola->top_similars($opts->{n_similar} || 3)->map(
    sub {$_->{entity_id} => $_->{similarity}}
  )->to_array->@*;

  my $top_n = $sch->resultset('CensoEscolas')->filter_by(co_entidade => [keys %topN])->get_all;

  # busca comentarios da feature
  my %comments = $sch->resultset('CensoEscolas')->comments->get_all->map(
    sub { 
      $_->{column_name} => $_->{column_comment} ||
      "Coluna $_->{column_name} sem comentários" 
    }
  )->@*;

  # monta tabela de apresentacao
  my $table=[["Nome Escola", "Escola Similar", "Similaridade", "distância"]];
  $top_n->each(
    sub {
      my $id   = $_->co_entidade;
      my $dist = $escola->distance_from({ lat => $_->latitude, lon => $_->longitude });
      push @$table,
      [
        $escola->no_entidade, $_->no_entidade, sprintf("%.2f", $topN{$id}),
        sprintf("%.2f km", $dist/1000)
      ];
    }
  );

  # exibe resultados
  say tablify($table);
  say $opts->{mostra_features} ? 
  do { 
    my $list = c(@$features)->map(
      sub {
        ref $_ ? "Coluna codificada: " . encode_json($_) 
               : "$_: " . ($comments{$_} || "Nenhum comentário encontrado")
      }
    );
    "Features avaliadas\n\n" . $list->join("\n");
  } : 'Features omitidas';
}

1;
