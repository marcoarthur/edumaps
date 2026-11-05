# t/01-app/config_snapshot.t
# ConfigSnapshot (t/lib): os testes rodam no mesmo banco da stack local e
# mexem na config; o helper devolve as linhas como estavam no fim do
# processo, inclusive o segredo cifrado (bytea).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use DBD::Pg ();
use utf8;

my $t   = Test::Mojo->new('EduMaps');
my $dbh = $t->app->schema->storage->dbh;
plan skip_all => 'app_config.items ausente (migration nao aplicada)'
  unless $dbh->selectrow_array("SELECT to_regclass('app_config.items')");

my $P      = "zz_teste_snapshot_$$";
my $SEGREDO = join '', map { chr } 0 .. 255;   # todos os bytes, inclusive \0

sub grava {
  my ($k, $v, $secret) = @_;
  my $sth = $dbh->prepare(q{INSERT INTO app_config.items (key, value, secret, sensitive, updated_by)
                            VALUES (?, ?::jsonb, ?, ?, 'teste')});
  $sth->bind_param(1, $k);
  $sth->bind_param(2, $v);
  $sth->bind_param(3, $secret, { pg_type => DBD::Pg::PG_BYTEA() });
  $sth->bind_param(4, defined $secret ? 1 : 0);
  $sth->execute;
}
sub estado {
  $dbh->selectall_arrayref(
    q{SELECT key, value::text, encode(secret, 'hex'), sensitive, secret_key_version, updated_by, updated_at::text
        FROM app_config.items WHERE key LIKE ? ORDER BY key}, {}, "$P.%");
}

END { $dbh->do('DELETE FROM app_config.items WHERE key LIKE ?', {}, "$P.%") if $dbh }

grava("$P.texto",   '"original"', undef);
grava("$P.segredo", 'null',       $SEGREDO);
my $antes = estado();
is scalar(@$antes), 2, 'duas chaves de teste';

# processo filho: fotografa, apaga uma, altera outra, cria uma terceira, sai
my $filho = <<"PERL";
use lib qw(t/lib lib);
use Imports;
use ConfigSnapshot;
use Test::Mojo;
my \$t = Test::Mojo->new('EduMaps');
my \$dbh = \$t->app->schema->storage->dbh;
ConfigSnapshot::guardar(\$dbh, '$P.%');
\$dbh->do(q{DELETE FROM app_config.items WHERE key = '$P.segredo'});
\$dbh->do(q{UPDATE app_config.items SET value = '"mudado"' WHERE key = '$P.texto'});
\$dbh->do(q{INSERT INTO app_config.items (key, value) VALUES ('$P.nova', '1')});
END { \$dbh->do(q{DELETE FROM app_config.items WHERE key LIKE '$P.%'}) }   # limpeza do próprio teste
PERL
is system($^X, '-e', $filho), 0, 'processo filho terminou bem';

is estado(), $antes, 'linhas de volta como estavam (valor, segredo, metadados)';
my ($bytes) = $dbh->selectrow_array('SELECT secret FROM app_config.items WHERE key = ?', {}, "$P.segredo");
is length($bytes // ''), 256, 'segredo binário íntegro';
ok $bytes eq $SEGREDO, 'mesmos bytes';

done_testing;
