# t/02-models/consentimento.t
# Consentimento versionado da autoinscrição (issue #214 — Fase 2, RF-208),
# role EduMaps::Roles::Business::Canal::Consentimento.
#
# Cobre: seed 1.0 vigente (hash = sha256 do texto), rascunho (validação,
# versão repetida), edição do rascunho (hash recalculado), publicação
# (rascunho -> vigente; anterior -> arquivada; vigente única), imutabilidade
# da publicada e o fallback sem vigente. Restaura a vigente original no fim.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Digest::SHA qw(sha256_hex);
use Encode qw(encode_utf8);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh   = $t->app->schema->storage->dbh;
my $has   = $dbh->selectrow_array("SELECT to_regclass('clean.consentimento_versoes')");
my $model = $t->app->model('Canal');

my $V = "t$$";   # prefixo das versões criadas pelo teste
my ($vigente_original) = $has
  ? $dbh->selectrow_array(q{SELECT id FROM clean.consentimento_versoes WHERE status = 'vigente'})
  : ();

sub restaura {
  return unless $has;
  $dbh->do(q{DELETE FROM clean.consentimento_versoes WHERE versao LIKE ?}, {}, "$V%");
  $dbh->do(q{UPDATE clean.consentimento_versoes SET status = 'vigente' WHERE id = ?},
           {}, $vigente_original) if $vigente_original;
}
END { restaura() }

subtest 'seed 1.0 vigente' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has;
  my $v = $model->consentimento_vigente;
  ok $v->{id}, 'há vigente';
  is $v->{status}, 'vigente', 'status';
  is $v->{texto_hash}, sha256_hex(encode_utf8($v->{texto})), 'hash = sha256 do texto (UTF-8)';
  like $v->{publicada_em}, qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, 'publicada_em ISO';
  my $seed = $dbh->selectrow_hashref(
    q{SELECT * FROM clean.consentimento_versoes WHERE versao = '1.0'});
  ok $seed, 'seed 1.0 existe';
  like $seed->{texto}, qr/consentimento/i, 'texto do seed';
};

subtest 'rascunho: criar, validar, editar (hash recalculado)' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has;

  is $model->consentimento_criar_rascunho(versao => '', texto => 'x')->{status}, 400, 'versao vazia';
  is $model->consentimento_criar_rascunho(versao => 'a b', texto => 'x')->{status}, 400, 'versao com espaço';
  is $model->consentimento_criar_rascunho(versao => "${V}a", texto => '  ')->{status}, 400, 'texto vazio';

  my $r = $model->consentimento_criar_rascunho(versao => "${V}a", texto => 'Texto A ção');
  ok $r->{id}, 'criado';
  is $r->{status}, 'rascunho', 'rascunho';
  ok !defined $r->{publicada_em}, 'sem publicada_em';
  is $r->{texto_hash}, sha256_hex(encode_utf8('Texto A ção')), 'hash do texto';

  is $model->consentimento_criar_rascunho(versao => "${V}a", texto => 'outro')->{status},
    409, 'versão repetida -> 409';

  my $e = $model->consentimento_editar_rascunho($r->{id}, texto => 'Texto B');
  is $e->{texto}, 'Texto B', 'texto editado';
  is $e->{texto_hash}, sha256_hex('Texto B'), 'hash recalculado';
  my $e2 = $model->consentimento_editar_rascunho($r->{id}, versao => "${V}b");
  is $e2->{versao}, "${V}b", 'versao editada';
  is $e2->{texto_hash}, $e->{texto_hash}, 'hash mantido sem mudar o texto';

  is $model->consentimento_editar_rascunho($r->{id})->{status}, 400, 'nada a alterar';
  is $model->consentimento_editar_rascunho($r->{id}, texto => '')->{status}, 400, 'texto inválido';
  ok !defined $model->consentimento_editar_rascunho(999999999, texto => 'x'), 'inexistente -> undef';

  my $outra = $model->consentimento_criar_rascunho(versao => "${V}c", texto => 'C');
  is $model->consentimento_editar_rascunho($outra->{id}, versao => "${V}b")->{status},
    409, 'renomear para versão existente -> 409';
};

subtest 'publicar: vira vigente, anterior arquivada; publicada imutável' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has;

  my $antes = $model->consentimento_vigente;
  my ($id) = $dbh->selectrow_array(
    q{SELECT id FROM clean.consentimento_versoes WHERE versao = ?}, {}, "${V}b");
  my $p = $model->consentimento_publicar($id);
  is $p->{status}, 'vigente', 'publicada é vigente';
  ok $p->{publicada_em}, 'publicada_em';

  is $model->consentimento_vigente->{id}, $id, 'nova vigente';
  is $dbh->selectrow_array(
    q{SELECT status FROM clean.consentimento_versoes WHERE id = ?}, {}, $antes->{id}),
    'arquivada', 'anterior arquivada';
  is $dbh->selectrow_array(
    q{SELECT count(*) FROM clean.consentimento_versoes WHERE status = 'vigente'}), 1,
    'vigente única';

  is $model->consentimento_publicar($id)->{status}, 409, 'publicar de novo -> 409';
  is $model->consentimento_editar_rascunho($id, texto => 'mudou')->{status}, 409,
    'vigente imutável';
  is $model->consentimento_editar_rascunho($antes->{id}, texto => 'mudou')->{status}, 409,
    'arquivada imutável';
  ok !defined $model->consentimento_publicar(999999999), 'inexistente -> undef';

  my $lista = $model->consentimento_listar;
  ok scalar(@$lista) >= 3, 'listar';
  ok $lista->[0]{id} > $lista->[-1]{id}, 'mais recente primeiro';

  # o banco garante a vigente única
  my $ok = eval {
    $dbh->do(q{UPDATE clean.consentimento_versoes SET status = 'vigente' WHERE id = ?},
             {}, $antes->{id});
    1;
  };
  ok !$ok, 'índice parcial impede duas vigentes';
};

subtest 'fallback sem vigente' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has;
  $dbh->begin_work;
  $dbh->do(q{UPDATE clean.consentimento_versoes SET status = 'arquivada' WHERE status = 'vigente'});
  my $v = $model->consentimento_vigente;
  is $v->{versao}, '1.0', 'fallback: constante 1.0';
  ok $v->{fallback}, 'marcado como fallback';
  ok !defined $v->{texto_hash}, 'sem hash';
  $dbh->rollback;
};

done_testing;
