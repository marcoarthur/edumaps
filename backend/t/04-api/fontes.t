# t/04-api/fontes.t
# #428 (AN-08): catálogo público das fontes. Ano/período vem da própria
# tabela; a carga, do import_metadata; nada interno vaza (caminho, nota,
# licença não verificada).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use EduMaps::Fontes;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

subtest 'GET /api/fontes: catálogo público' => sub {
  my $tx = $t->get_ok('/api/fontes')->status_is(200)
    ->header_like('Cache-Control' => qr/max-age=600/)->tx;
  my $r = $tx->res->json;
  is [map { $_->{id} } @$r], [qw(censo ideb inse siope ibge_malha ibge_populacao)], 'bases e ordem';

  my ($censo) = grep { $_->{id} eq 'censo' } @$r;
  my ($ano) = $dbh->selectrow_array('SELECT max(nu_ano_censo)::text FROM clean.censo_escolas');
  is $censo->{periodo}{fim}, $ano, 'ano do Censo lido da tabela';
  like $censo->{url}, qr{^https://www\.gov\.br/inep/}, 'link oficial';
  ok( (grep { $_ eq 'comparacao_redes' } @{ $censo->{telas} }), 'telas que usam a base');

  my $corpo = $tx->res->body;
  unlike $corpo, qr{/srv/|/tmp/|/data/|"caminho"|"notes"|Loader}, 'nenhum caminho ou nota interna';
  unlike $corpo, qr/n[ãa]o verificad|pendente|DECIS/i, 'nenhuma situação de licença interna';
};

subtest 'licença só quando verificada' => sub {
  is EduMaps::Fontes::licenca_publica('CC-BY-4.0 (ANTT)'), 'CC-BY-4.0 (ANTT)', 'verificada passa';
  is EduMaps::Fontes::licenca_publica('Não verificada'), undef, 'não verificada some';
  is EduMaps::Fontes::licenca_publica('Não verificada (e-SIC INEP pendente; uso interno)'), undef, 'pendente some';
  is EduMaps::Fontes::licenca_publica('Public Domain / DECISÃO JURÍDICA PENDENTE'), undef, 'decisão pendente some';
  is EduMaps::Fontes::licenca_publica('-'), undef, 'traço some';
};

subtest 'arquivos do manifesto sem o caminho' => sub {
  my $a = EduMaps::Fontes::arquivos_publicos(
    '[{"url":"https://x/y.zip","sha256":"abc","bytes":10,"caminho":"/srv/edumaps/raw/y.zip","baixado_em":"2026-11-13","reaproveitado":true},{"url":"sem hash"}]');
  is $a, [{ url => 'https://x/y.zip', sha256 => 'abc', bytes => 10, baixado_em => '2026-11-13' }],
    'só url, sha256, bytes e data; sem hash fica de fora';
  is EduMaps::Fontes::arquivos_publicos(undef), [], 'sem manifesto';
};

subtest 'carga não registrada não é inventada' => sub {
  my $r = EduMaps::Fontes->resolver($dbh);
  for my $f (@$r) {
    my $tem = 0;
    for my $tab (@{ (grep { $_->{id} eq $f->{id} } @EduMaps::Fontes::CATALOGO)[0]{tabelas} }) {
      $tem ||= $dbh->selectrow_array(
        q{SELECT 1 FROM clean.import_metadata WHERE table_name = ? AND COALESCE(ultimo_status,'ok') = 'ok'}, {}, $tab);
    }
    if ($tem) { like $f->{carga}{data}, qr/^\d{4}-\d{2}-\d{2}$/, "$f->{id}: data da carga" }
    else      { is $f->{carga}, undef, "$f->{id}: sem registro, carga nula" }
  }
};

done_testing;
