use Mojo::Base -strict, -signatures;
use lib qw(../../lib);
use EduMaps::Schema qw();
use Minion;
use open ':std', ':encoding(UTF-8)';
use DDP;

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

my $pg_url = sprintf("postgresql://%s:%s@%s/%s", $info{db_user}, $info{db_pass}, $info{host},$info{dbname});
my $minion = Minion->new(Pg => $pg_url);
$minion->backoff(sub ($retries) { return ($retries ** 2) + 3; });

my $cities_without_siope = $sch->resultset('MunicipiosSp')
->anti_join('remuneracao_educacao')
->columns([qw(codigo_ibge_antigo nome_municipio codigo_ibge)])
->random_sample(10)
;

my $results = $cities_without_siope->as_hash->get_all->each(
  sub ($city, $idx) {
    my $year = 2025;
    my $siope_id = $minion->enqueue(
      query_siope => [$city->{codigo_ibge_antigo}, $year] => { attempts => 3 }
    );
    $city->{siope_id} = $siope_id;
    # my $osm_id = $minion->enqueue(
    #   query_osm => [$city->{codigo_ibge}] => { attempts => 3 }
    # );
    # $city->{osm_id} = $osm_id;
  }
);


p $results;
