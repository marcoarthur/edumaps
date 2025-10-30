#!/usr/bin/env perl

use Mojo::Base -strict, -signatures;

use Getopt::Long;
use Pod::Usage;
use DBIx::Class::Schema::Loader qw/ make_schema_at /;
use open ':std', ':encoding(UTF-8)';
use Mojo::File qw(path);

my %options = (
  conf        => 'config/loader.ini',
  tolib       => '../backend/lib',
  namespace   => 'EduMaps::Schema',
  db_schema   => ['clean'],
  debug       => 0,
  help        => 0,
);

GetOptions(
  'conf=s'        => \$options{conf},
  'tolib=s'       => \$options{tolib},
  'namespace=s'   => \$options{namespace},
  'schema=s@'     => \$options{db_schema},
  'table=s'       => \$options{constraint},
  'component=s@'  => \$options{components},
  'debug'         => \$options{debug},
  'help|h'        => \$options{help},
) or pod2usage(2);

pod2usage(1) if $options{help};

# Carregar configuração do banco
my $db_config = load_db_config($options{conf});
my @db_params = (
  $db_config->{dsn},
  $db_config->{user},
  $db_config->{password},
  $db_config->{options} || {},
);

say "🎯 Gerando classes DBIx::Class para: $options{namespace}";
say "📁 Output: $options{tolib}";
say "🗃️  Schemas: " . join(', ', @{$options{db_schema}});
say "🔗 DSN: $db_config->{dsn}";

# Criar diretório de output se não existir
path($options{tolib})->make_path unless -d $options{tolib};

eval {
  make_schema_at(
    $options{namespace},
    {
      db_schema        => $options{db_schema},
      debug            => $options{debug},
      relationships    => 1,
      use_namespaces   => 1,
      dump_directory   => $options{tolib},
      generate_pod     => 1,
      overwrite_modifications => 1,
      moniker_map      => sub {
        my ($table, $default) = @_;
        # Converter snake_case para CamelCase
        $table =~ s/(?:^|_)([a-z])/\U$1/g;
        return $table;
      },
    },
    \@db_params
  );

  say "✅ Classes DBIx::Class geradas com sucesso!";
  say "📊 Localização: $options{tolib}/" . ($options{namespace} =~ s/::/\//gr);

};

if ($@) {
  die "❌ Erro ao gerar classes: $@\n";
}

sub load_db_config {
  my ($config_file) = @_;

  die "❌ Arquivo de configuração '$config_file' não encontrado\n" unless -f $config_file;

  # Tentar diferentes formatos de configuração
  my $config;

  # Formato INI (Config::Tiny)
  eval {
    require Config::Tiny;
    my $ini = Config::Tiny->read($config_file);
    if ($ini && $ini->{database}) {
      $config = {
        dsn      => "dbi:Pg:dbname=$ini->{database}->{name};host=$ini->{database}->{host};port=$ini->{database}->{port}",
        user     => $ini->{database}->{user},
        password => $ini->{database}->{password},
        options  => { AutoCommit => 1, RaiseError => 1 },
      };
    }
  };

  # Formato YAML
  if (!$config) {
    eval {
      require YAML::XS;
      my $yaml = YAML::XS::LoadFile($config_file);
      if ($yaml->{database}) {
        $config = {
          dsn      => $yaml->{database}->{dsn} || "dbi:Pg:dbname=$yaml->{database}->{name};host=$yaml->{database}->{host}",
          user     => $yaml->{database}->{user},
          password => $yaml->{database}->{password},
          options  => { AutoCommit => 1, RaiseError => 1 },
        };
      }
    };
  }

  # Formato simples DSN (fallback)
  if (!$config) {
    open my $fh, '<', $config_file or die "Não pode abrir $config_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    if ($content =~ /dsn=([^\n]+)/) {
      $config = {
        dsn      => $1,
        user     => $content =~ /user=([^\n]+)/ ? $1 : '',
        password => $content =~ /password=([^\n]+)/ ? $1 : '',
        options  => { AutoCommit => 1, RaiseError => 1 },
      };
    }
  }

  die "❌ Não foi possível carregar configuração do banco de $config_file\n" unless $config;

  return $config;
}

__END__

=head1 NAME

loader.pl - Gera classes DBIx::Class a partir do schema do banco

=head1 SYNOPSIS

# Uso básico com config padrão
./bin/loader.pl

# Especificar arquivo de configuração
./bin/loader.pl --conf config/production.conf

# Output personalizado
./bin/loader.pl --tolib ../lib --namespace MyApp::Schema

# Apenas tabelas específicas
./bin/loader.pl --table countries --table municipios_sp

# Gerar para schemas específicos
./bin/loader.pl --schema clean --schema analytics

# Debug
./bin/loader.pl --debug

=head1 OPTIONS

=over 4

=item B<--conf>=I<file>

Arquivo de configuração do banco (padrão: config/database.conf)

=item B<--tolib>=I<path>

Diretório de output para as classes (padrão: ./lib)

=item B<--namespace>=I<namespace>

Namespace para as classes (padrão: EduMaps::Schema)

=item B<--schema>=I<schema>

Schema(s) do banco para gerar classes (pode ser usado múltiplas vezes)

=item B<--table>=I<table>

Filtrar por tabela específica (pode ser usado múltiplas vezes)

=item B<--component>=I<component>

Componentes adicionais para as classes

=item B<--debug>

Ativar modo debug

=item B<--help>

Mostrar esta ajuda

=back

=head1 CONFIG FILE FORMAT

Suporta INI, YAML ou formato simples:

Formato INI (Config::Tiny):
[database]
name = edumaps_dev
host = localhost
port = 5432
user = edumaps_user
password = senha

Formato YAML:
database:
dsn: dbi:Pg:dbname=edumaps_dev;host=localhost
user: edumaps_user
password: senha

Formato simples:
dsn=dbi:Pg:dbname=edumaps_dev;host=localhost
user=edumaps_user
password=senha

=cut
