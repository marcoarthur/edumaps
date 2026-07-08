#!/usr/bin/env perl
use strict;
use warnings;

use Test2::V0;
use Test2::Mock;
use Test2::Tools::Exception qw(dies lives);

use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);
use Mojo::File qw(path);

use ok('EduMaps::Analysis::R::Pipe');

# ----------------------------------------------------------------------
# Setup: criar arquivo R de teste
# ----------------------------------------------------------------------
my $temp_dir = tempdir(CLEANUP => 1);
my $r_source = 'test.R';
my $r_file   = catfile($temp_dir, $r_source);

{
  open my $fh, '>', $r_file or die "Cannot create $r_file: $!";
  print $fh "print('Hello from source')\n";
  close $fh;
}

# ----------------------------------------------------------------------
# Teste 1: Execução com sucesso
# ----------------------------------------------------------------------
subtest 'Execução com sucesso' => sub {
  my $mock = Test2::Mock->new(
    class => 'IPC::Run',
    track => 1,
    override => [
      run => sub { return 1 }   # sucesso
    ]
  );

  my $pipe = EduMaps::Analysis::R::Pipe->new;
  my $args = {
    paths       => [$temp_dir],
    source_file => $r_source,
    script      => 'print("User script")',
  };

  ok( lives { $pipe->run($args) }, 'run executa com sucesso' );

  my $calls = $mock->call_tracking;
  is( scalar @$calls, 1, 'IPC::Run::run foi chamado uma vez' );

  my $call = $calls->[0];
  my $cmd_args = $call->{args}[0];  # arrayref dos argumentos do comando
  is( $cmd_args->[0], 'Rscript', 'primeiro argumento é Rscript' );
  is( $cmd_args->[1], '--vanilla', 'segundo argumento é --vanilla' );

  # my $script_tmp = $cmd_args->[2];  # objeto Mojo::File
  # ok( -f $script_tmp->to_string, 'script temporário existe' );
  #
  # # Limpeza opcional
  # unlink $script_tmp->to_string if -f $script_tmp->to_string;
};

# ----------------------------------------------------------------------
# Teste 2: Falha na execução do Rscript
# ----------------------------------------------------------------------
subtest 'Falha na execução' => sub {
  my $mock = Test2::Mock->new(
    class => 'IPC::Run',
    override => [
      run => sub {
        my (@args) = @_;
        # Último argumento é referência para $err
        my $err_ref = pop @args;
        $$err_ref = 'Erro simulado do R';
        return 0;
      }
    ]
  );

  my $pipe = EduMaps::Analysis::R::Pipe->new;
  my $args = {
    paths       => [$temp_dir],
    source_file => $r_source,
    script      => 'print("User script")',
  };

  like(
    dies { $pipe->run($args) },
    qr/Rscript failed: Erro simulado do R/,
    'lança exceção com mensagem de erro'
  );
};

# ----------------------------------------------------------------------
# Teste 3: Arquivo fonte não encontrado
# ----------------------------------------------------------------------
subtest 'Arquivo fonte não encontrado' => sub {
  my $pipe = EduMaps::Analysis::R::Pipe->new;
  my $args = {
    paths       => [$temp_dir],
    source_file => 'nao_existe.R',
    script      => 'print("User script")',
  };

  like(
    dies { $pipe->run($args) },
    qr/Not found/i,
    'lança exceção quando arquivo não encontrado'
  );
};

# ----------------------------------------------------------------------
# Teste 4: Conteúdo do script temporário
# ----------------------------------------------------------------------
subtest 'Conteúdo do script temporário' => sub {
  my $mock = Test2::Mock->new(
    class => 'IPC::Run',
    override => [
      run => sub {
        my (@args) = @_;
        # args[0] é a lista de comando (arrayref)
        my $cmd_args = $args[0];
        my $script_tmp = $cmd_args->[2];  # objeto Mojo::File
        die "script_tmp não é um Mojo::File" unless ref($script_tmp) eq 'Mojo::File';
        my $content = $script_tmp->slurp;
        like( $content, qr/source\(.*$r_source.*\)/, 'contém source com nome do arquivo' );
        like( $content, qr/print\("User script"\)/, 'contém script do usuário' );
        return 1;
      }
    ]
  );

  my $pipe = EduMaps::Analysis::R::Pipe->new;
  my $args = {
    paths       => [$temp_dir],
    source_file => $r_source,
    script      => 'print("User script")',
  };

  ok( lives { $pipe->run($args) }, 'execução com verificação de conteúdo' );
};

# ----------------------------------------------------------------------
# Teste 5: Paths vazio
# ----------------------------------------------------------------------
subtest 'Paths vazio' => sub {
  my $pipe = EduMaps::Analysis::R::Pipe->new;
  my $args = {
    paths       => [],
    source_file => $r_source,
    script      => 'print("User script")',
  };

  like(
    dies { $pipe->run($args) },
    qr/Not found/i,
    'lança exceção com paths vazio'
  );
};

done_testing;
