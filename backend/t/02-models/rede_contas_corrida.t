# t/02-models/rede_contas_corrida.t
# #593: a listagem das contas de rede não cai inteira quando uma conta some
# entre a lista de ids e a busca de cada uma (corrida com outro processo que
# apaga a conta). Simula o sumiço: a primeira busca apaga a outra conta.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
skip_all('clean.rede_vinculos ausente') unless $dbh->selectrow_array("SELECT to_regclass('clean.rede_vinculos')");

my $P = sprintf '%04d', $$ % 10000;
my @EMAILS = ("aaa.corrida.$P\@edumaps.test", "zzz.corrida.$P\@edumaps.test");
my $limpa = sub { $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?)', {}, @EMAILS) };
$limpa->();
END { $limpa->() if $dbh }

my @ids = map {
  $dbh->selectrow_array(q{INSERT INTO clean.gestores (cod_inep, nome, email, access_role)
                          VALUES (60059301, ?, ?, 'rede') RETURNING id}, undef, "Conta $_", $EMAILS[$_]);
} 0, 1;

my $m = $t->app->build_controller->model("Pesquisa");
my $class = ref $m;
my $orig = $class->can('rede_conta');
{
  no warnings 'redefine';
  no strict 'refs';
  my $feito = 0;
  # Na primeira busca, outro "processo" apaga a segunda conta.
  local *{"${class}::rede_conta"} = sub ($self, $id) {
    $dbh->do('DELETE FROM clean.gestores WHERE id = ?', {}, $ids[1]) unless $feito++;
    return $orig->($self, $id);
  };
  my $contas = eval { $m->rede_contas };
  ok !$@, 'a listagem não cai com a conta que sumiu' or diag $@;
  my @minhas = grep { $_->{email} =~ /corrida\.$P/ } @{ $contas // [] };
  is [ map { $_->{id} } @minhas ], [ $ids[0] ], 'a conta que existe continua na lista';
}

done_testing;
