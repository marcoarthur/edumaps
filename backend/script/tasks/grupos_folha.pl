use Mojo::Base -strict, -signatures;
use lib qw(../../lib);
use EduMaps::Schema qw();
use Minion;
use Mojo::JSON qw(encode_json);
use open ':std', ':encoding(UTF-8)';

# Backfill dos grupos pré-listados da folha de pagamento.
# Enfileira um job seed_grupos_folha por escola com dados na
# remuneracao_municipal que ainda não tem grupos de origem 'folha'.
# O job é idempotente (UNIQUE cod_inep, nome em contato_grupos).

my $sch = EduMaps::Schema->go;
my %info;
my $connect_info = $sch->storage->connect_info;
foreach my $db_info (split(/;/, $connect_info->[0])) {
  my @kv = split(/=/, $db_info);
  next unless @kv >= 2;
  $kv[0] =~ s/.*://g;
  $info{$kv[0]} = $kv[1];
}
$info{db_user} = $connect_info->[1];
$info{db_pass} = $connect_info->[2];
$info{opts} = $connect_info->[3];

my $pg_url = sprintf("postgresql://%s:%s@%s/%s", $info{db_user}, $info{db_pass}, $info{host}, $info{dbname});
my $minion = Minion->new(Pg => $pg_url);
$minion->backoff(sub ($retries) { return ($retries ** 2) + 3; });

my $schools = $sch->storage->dbh->selectcol_arrayref(q{
  SELECT DISTINCT r.cod_inep
  FROM   clean.remuneracao_municipal r
  JOIN   clean.gestores g ON g.cod_inep = r.cod_inep
  WHERE  NOT EXISTS (
    SELECT 1 FROM clean.contato_grupos cg
    WHERE  cg.cod_inep = r.cod_inep AND cg.origem = 'folha'
  )
});

my @enqueued;
for my $inep (@$schools) {
  push @enqueued, {
    cod_inep => $inep + 0,
    job_id   => $minion->enqueue(seed_grupos_folha => [$inep + 0] => { attempts => 3 }),
  };
}

print encode_json(\@enqueued), "\n";
printf "Enfileirados %d jobs (seed_grupos_folha)\n", scalar @enqueued;