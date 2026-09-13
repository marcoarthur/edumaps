package EduMaps::Plugin::Analytics;
use utf8;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::UserAgent;
use Scalar::Util qw(weaken);

use constant {
  DEFAULT_URL            => 'http://analytic:8000',
  DEFAULT_TIMEOUT        => 300,
  DEFAULT_SOURCE_VERSION => 'edumapsr-0.1.0',
  DEFAULT_ENGINE         => 'pipe',
};

has [qw(url timeout source_version cache_enabled)];
has ua => sub {
  Mojo::UserAgent->new(inactivity_timeout => shift->timeout);
};

sub register ($self, $app, @args) {
  my $conf = $app->config;

  $self->url(         $conf->{analytics_url}          // DEFAULT_URL);
  $self->timeout(     $conf->{analytics_timeout}      // DEFAULT_TIMEOUT);
  $self->source_version($conf->{analytics_source_version} // DEFAULT_SOURCE_VERSION);
  $self->cache_enabled($conf->{analytics_cache_enabled} // 1);

  # Motor usado pelas tasks R: 'http' (Plumber/edumapsr via Client) ou
  # 'pipe' (legado via EduMaps::Analysis::R::Pipe — padrão, não exige o
  # serviço analítico de pé). Feature flag: manter os dois motores.
  my $engine = $conf->{analytics_engine} // DEFAULT_ENGINE;
  $self->{engine} = $engine eq 'http' ? 'http' : 'pipe';

  $self->ua(Mojo::UserAgent->new(inactivity_timeout => $self->timeout));

  weaken($app);
  require EduMaps::Analytics::Client;
  my $client = EduMaps::Analytics::Client->new(
    url            => $self->url,
    timeout        => $self->timeout,
    source_version => $self->source_version,
    cache_enabled  => $self->cache_enabled,
    app            => $app,
  );

  $app->helper(
    analytics => sub {
      return $client;
    }
  );

  $app->helper(
    analytics_engine => sub {
      return $self->{engine};
    }
  );
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Plugin::Analytics - Conector síncrono do backend web para o serviço analítico (Plumber/edumapsr)

=head1 SYNOPSIS

    # No startup (EduMaps.pm)
    $self->plugin("EduMaps::Plugin::Analytics");

    # Em qualquer controller/task
    my $result = $c->analytics->run_cluster({
        schema     => 'staging',
        table_name => 'censo_escolas',
        id_column  => 'co_entidade',
        parameters => { algorithm => 'kmeans', clusters => 4 },
    });

    my $summary = $c->analytics->run_summary({ codigo_ibge => '3550308' });

    my $pairs = $c->analytics->run_similarity_db({
        schema     => 'staging',
        table_name => 'censo_escolas',
        id_column  => 'co_entidade',
        features   => ['qt_mat_bas', 'tp_dependencia'],
    });

=head1 DESCRIPTION

Pontuação de um lado: o backend web (Perl) passa a conversar com o serviço
analítico Plumber (L<edumapsr>) via HTTP síncrono, em vez de disparar
processos Rscript via L<EduMaps::Analysis::R::Pipe>. As execuções de
cluster/city_summary têm leitura-through no cache compartilhado
C<analytics.analysis_cache> (chave = sha1 de {análise, parâmetros
canônicos, source_version}). Similaridade (pares O(n²)) nunca é cacheada:
só é persistida em C<analytics.similarity_pairs>.

Configuração (C<edu_maps.conf>):

=over 4

=item * C<analytics_url> - base URL do serviço Plumber (default: C<http://analytic:8000>)

=item * C<analytics_timeout> - timeout de cada chamada HTTP em segundos (default: 300)

=item * C<analytics_source_version> - versão do pacote/scripts R; invalida o cache (default: edumapsr-0.1.0)

=item * C<analytics_cache_enabled> - liga/desliga o cache compartilhado (default: 1)

=item * C<analytics_engine> - motor das tasks de análise: C<http> (Plumber/
edumapsr, via L<EduMaps::Analytics::Client>) ou C<pipe> (legado R::Pipe,
default). Ajudante C<analytics_engine> expõe o valor à aplicação.

=back

=cut