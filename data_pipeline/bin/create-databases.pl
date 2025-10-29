#!/usr/bin/env perl

use Mojo::Base -strict, -signatures;
use utf8;

use Config::Tiny;  # Para ler arquivo .conf
use Try::Tiny;     # Para tratamento elegante de erros
use DBI;           # Para verificar/conectar ao PostgreSQL
use open ':std', ':encoding(UTF-8)';  # Corrige encoding da saída

# Caminho do arquivo de configuração
my $config_file = 'config/database.ini';

sub main {

  my $force_recreate = @ARGV && $ARGV[0] eq '--force';
  say "🔄 Iniciando criação dos bancos de dados para EduMaps...";

  # Carregar configurações
  my $config = load_config($config_file);

  # Verificar conexão com o PostgreSQL
  check_postgres_connection($config);

  # Criar usuário da aplicação se não existir
  create_app_user($config);

  # Criar bancos de dados
  create_database($config, 'edumaps_dev', $force_recreate);
  create_database($config, 'edumaps_prod', $force_recreate);

  say "✅ Todos os bancos criados com sucesso!";
  say "📊 Bancos disponíveis: edumaps_dev, edumaps_prod";
  say "👤 Usuário: " . $config->{app_user}->{name};
}

sub load_config {
  my ($file) = @_;

  die "❌ Arquivo de configuração '$file' não encontrado!\n" unless -f $file;

  my $config = Config::Tiny->read($file, 'utf8');
  die "❌ Erro ao ler arquivo de configuração: $!\n" unless $config;

  say "📁 Configuração carregada de: $file";
  return $config;
}

sub check_postgres_connection {
  my ($config) = @_;

  my $server = $config->{server};
  my $dsn = "dbi:Pg:host=$server->{host};port=$server->{port}";

  say "🔌 Conectando ao PostgreSQL em $server->{host}:$server->{port}...";

  try {
    my $dbh = DBI->connect(
      $dsn,
      $server->{user},
      $server->{password},
      { RaiseError => 1, PrintError => 0 }
    );

    my $version = $dbh->selectrow_array('SELECT version()');
    say "✅ PostgreSQL conectado: $version";
    $dbh->disconnect;
  }
  catch {
    die "❌ Falha ao conectar no PostgreSQL: $_\n";
  };
}

sub create_app_user {
  my ($config) = @_;

  my $server = $config->{server};
  my $user = $config->{app_user};

  my $dsn = "dbi:Pg:host=$server->{host};port=$server->{port}";

  try {
    my $dbh = DBI->connect($dsn, $server->{user}, $server->{password});

    # Verificar se usuário já existe
    my $user_exists = $dbh->selectrow_array(
      "SELECT 1 FROM pg_roles WHERE rolname = ?", 
      undef, $user->{name}
    );

    if ($user_exists) {
      say "👤 Usuário '$user->{name}' já existe";
    }
    else {
      # Criar usuário
      $dbh->do("CREATE USER $user->{name} WITH PASSWORD '$user->{password}'");
      say "👤 Usuário '$user->{name}' criado com sucesso";
    }

    $dbh->disconnect;
  }
  catch {
    warn "⚠️  Aviso ao criar usuário: $_\n";
  };
}

sub create_database {
  my ($config, $db_name, $force_recreate) = @_;

  my $server = $config->{server};
  my $db_config = $config->{"databases.$db_name"};
  my $user = $config->{app_user}->{name};

  say "🗃️  Verificando banco: $db_name...";

  # Verificar se o banco já existe
  if (database_exists($config, $db_name)) {
    if ($force_recreate) {
      say "♻️  Banco existe, forçando recriação...";
      drop_database($config, $db_name);
    }
    else {
      say "⚠️  Banco '$db_name' já existe, pulando criação...";
      return;
    }
  }

  say "📦 Criando banco: $db_name...";

  # Montar comando createdb
  my @cmd = (
    'createdb',
    '-h', $server->{host},
    '-p', $server->{port},
    '-U', $server->{user},
    '-E', $db_config->{encoding},
    '-T', $db_config->{template},
    '-O', $user,
    $db_name
  );

  # Configurar variável de ambiente para password se necessário
  local $ENV{PGPASSWORD} = $server->{password} if $server->{password};

  # Executar comando
  my $exit_code = system(@cmd);

  if ($exit_code == 0) {
    say "✅ Banco '$db_name' criado com sucesso";

  }
  else {
    die "❌ Erro ao criar banco '$db_name' (código: $exit_code)";
  }
}

sub database_exists {
  my ($config, $db_name) = @_;

  my $server = $config->{server};

  try {
    my $dsn = "dbi:Pg:host=$server->{host};port=$server->{port};dbname=postgres";
    my $dbh = DBI->connect(
      $dsn, 
      $server->{user}, 
      $server->{password},
      { RaiseError => 0, PrintError => 0 }
    );

    return 0 unless $dbh;  # Falha na conexão

    # Verificar se o banco existe
    my $exists = $dbh->selectrow_array(
      "SELECT 1 FROM pg_database WHERE datname = ?", 
      undef, $db_name
    );

    $dbh->disconnect;
    return $exists ? 1 : 0;
  }
  catch {
    # Em caso de erro, assumir que não existe
    return 0;
  };
}

sub add_postgis_extensions {
  my ($config, $db_name) = @_;

  my $server = $config->{server};
  my $dsn = "dbi:Pg:host=$server->{host};port=$server->{port};dbname=$db_name";

  try {
    my $dbh = DBI->connect($dsn, $server->{user}, $server->{password});

    # Adicionar extensões essenciais para GeoDados
    for my $ext (qw(postgis postgis_topology fuzzystrmatch postgis_tiger_geocoder)) {
      $dbh->do("CREATE EXTENSION IF NOT EXISTS $ext");
    }

    say "🧩 Extensões PostGIS adicionadas ao '$db_name'";
    $dbh->disconnect;
  }
  catch {
    say "⚠️  Aviso: Não foi possível adicionar PostGIS ao '$db_name': $_";
  };
}

sub drop_database {
  my ($config, $db_name) = @_;

  my $server = $config->{server};

  # Terminar conexões existentes primeiro
  my $dsn = "dbi:Pg:host=$server->{host};port=$server->{port};dbname=postgres";
  my $dbh = DBI->connect($dsn, $server->{user}, $server->{password});

  $dbh->do("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = ?", 
    undef, $db_name);

  $dbh->disconnect;

  # Agora dropar o banco
  my @cmd = (
    'dropdb',
    '-h', $server->{host},
    '-p', $server->{port}, 
    '-U', $server->{user},
    $db_name
  );

  local $ENV{PGPASSWORD} = $server->{password} if $server->{password};
  system(@cmd);

  say "🗑️  Banco '$db_name' removido";
}

# Executar script
main();
