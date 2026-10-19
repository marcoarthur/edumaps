use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::Log;
use Mojo::File qw(path);
use File::Temp qw(tempdir);
use File::Spec;

# =================================================================
# Base: run_perl_script / run_r_script — morte por SINAL vs exit code.
#
# O `$? >> 8` dá 0 quando o filho morre por sinal (o dash faz `exec` do
# comando final, logo o filho direto do Perl é o próprio script), então
# o job seguia como SUCESSO: em 2026-10-19 o R de SP/RJ/PE morreu com
# SIGKILL (OOM) e o CSV do bloco anterior foi lido como se fosse do
# bloco novo. Regressão do fix.
# =================================================================

use_ok('EduMaps::Ingestion::Job::Base');

my $dir = tempdir(CLEANUP => 1);

sub script {
  my ($nome, $corpo) = @_;
  my $p = File::Spec->catfile($dir, $nome);
  path($p)->spew($corpo);
  return $p;
}

# max_retries => 0: a primeira falha já aborta (sem sleeps de backoff no teste)
sub base {
  my %extra = @_;
  EduMaps::Ingestion::Job::Base->new(
    log => Mojo::Log->new(level => 'fatal'), max_retries => 0, backoff_base => 0, %extra);
}

# ------------------------------------------------- convenção do $? (unidade)
{
  my $j = base();
  eval { $j->_abortar_se_morreu_por_sinal(0, 'R x', 'tudo bem') };
  ok(!$@, 'status 0 não aborta');
  eval { $j->_abortar_se_morreu_por_sinal(3 << 8, 'R x', 'parcial') };
  ok(!$@, 'exit code é assunto do caller, não do cheque de sinal');
  eval { $j->_abortar_se_morreu_por_sinal(9, 'R x', "antes do kill\n") };
  like($@, qr/^R x morreu por sinal 9 \(SIGKILL — provável OOM: ver lotes\/memória\)\. Última saída:\nantes do kill/,
    'SIGKILL morre alto, com a saída do script');
  eval { $j->_abortar_se_morreu_por_sinal(11, 'R x', '') };
  like($@, qr/morreu por sinal 11 \(SIGSEGV\)\. Última saída:\n\(sem saída\)/,
    'SIGSEGV morre alto; saída vazia vira marcador');
}

# ------------------------------------------------- run_perl_script (integração)
{
  my $p = script('ok.pl', "print \"feito\\n\"; exit 0;\n");
  is(base()->run_perl_script($p), "feito\n", 'exit 0 devolve a saída');
}

{
  my $p = script('falha.pl', "print \"parcial\\n\"; exit 3;\n");
  eval { base()->run_perl_script($p) };
  like($@, qr/falhou \(exit 3\)/, 'exit code continua falhando alto');
  like($@, qr/parcial/, 'a saída vai junto no erro');
}

{
  # STDERR porque o stdout de pipe é bufferizado: com SIGKILL o buffer nunca
  # descarrega, e o teste é sobre o que o script consegue escrever antes.
  my $p = script('kill9.pl', "print STDERR \"antes do kill\\n\"; kill 9, \$\$;\n");
  eval { base()->run_perl_script($p) };
  # sob dash o sinal chega como sinal; sob bash como "exit 137" — os dois
  # têm de falhar alto, o proibido é o silêncio.
  like($@, qr/morreu por sinal 9 \(SIGKILL — provável OOM|exit 137/,
    'SIGKILL nunca passa como sucesso');
  like($@, qr/antes do kill/, 'a saída antes do kill vai junto no erro');
}

{
  my $p = script('kill11.pl', "kill 11, \$\$;\n");
  eval { base()->run_perl_script($p) };
  like($@, qr/morreu por sinal 11 \(SIGSEGV\)|exit 139/, 'SIGSEGV nunca passa como sucesso');
}

{
  my $p = script('dry.pl', "print \"nao devo rodar\\n\";\n");
  is(base(dry_run => 1)->run_perl_script($p), 'DRY-RUN OK', 'dry-run não executa');
}

done_testing;
