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
use EduMaps::Model::Rank::School;
use EduMaps::Model::Ivet::Versao;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

subtest 'GET /api/fontes: catálogo público' => sub {
  my $tx = $t->get_ok('/api/fontes')->status_is(200)
    ->header_like('Cache-Control' => qr/max-age=600/)->tx;
  my $r = $tx->res->json;
  is [map { $_->{id} } @$r], [qw(censo ideb inse siope ibge_malha ibge_populacao indices_edumaps ivet_edumaps)], 'bases e ordem';

  my ($censo) = grep { $_->{id} eq 'censo' } @$r;
  my ($ano) = $dbh->selectrow_array('SELECT max(nu_ano_censo)::text FROM clean.censo_escolas');
  is $censo->{periodo}{fim}, $ano, 'ano do Censo lido da tabela';
  like $censo->{url}, qr{^https://www\.gov\.br/inep/}, 'link oficial';
  ok( (grep { $_ eq 'comparacao_redes' } @{ $censo->{telas} }), 'telas que usam a base');

  my $corpo = $tx->res->body;
  unlike $corpo, qr{/srv/|/tmp/|/data/|"caminho"|"notes"|Loader}, 'nenhum caminho ou nota interna';
  unlike $corpo, qr/n[ãa]o verificad|pendente|DECIS/i, 'nenhuma situação de licença interna';
};

subtest 'SIOPE (#512): a lista de municípios com folha' => sub {
  my ($s) = grep { $_->{id} eq 'siope' } @{ $t->get_ok('/api/fontes')->tx->res->json };
  is ref $s->{cobertura}, 'ARRAY', 'cobertura no cartão do SIOPE';
  like $s->{descricao}, qr/listados abaixo/, 'a descrição aponta a lista';
  for my $m (@{ $s->{cobertura} }) {
    like $m->{codigo_ibge}, qr/^\d{7}$/, "código IBGE ($m->{municipio})";
    ok @{ $m->{anos} }, 'com os anos';
  }
  my ($censo) = grep { $_->{id} eq 'censo' } @{ $t->get_ok('/api/fontes')->tx->res->json };
  ok !exists $censo->{cobertura}, 'só o SIOPE tem a lista';
};

subtest 'índices do EduMaps (#462): versão citável' => sub {
  my ($i) = grep { $_->{id} eq 'indices_edumaps' } @{ $t->get_ok('/api/fontes')->tx->res->json };
  is $i->{orgao}, 'EduMaps', 'base própria';
  ok $i->{proprio}, 'marcada como própria';
  is $i->{versao}, $EduMaps::Model::Rank::School::INDICES_VERSAO, 'versão do registro';
  like $i->{data}, qr/^\d{4}-\d{2}-\d{2}$/, 'data da versão';
  is [ map { $_->{versao} } @{ $i->{historico} } ],
    [ map { $_->{versao} } @EduMaps::Model::Rank::School::INDICES_HISTORICO ], 'histórico completo';
  like $i->{url}, qr{rankings\.md#o-que-cada}, 'link para o método';
  my ($ano) = $dbh->selectrow_array('SELECT max(nu_ano_censo)::text FROM clean.mv_escolas_scores');
  is $i->{periodo}{fim}, $ano, 'ano do Censo dos índices';
  my ($mat) = $dbh->selectrow_array(q{SELECT to_char(max(data_atualizacao) AT TIME ZONE 'America/Sao_Paulo', 'YYYY-MM-DD') FROM clean.mv_escolas_scores});
  is $i->{carga} ? $i->{carga}{data} : undef, $mat, 'carga = última materialização';
  my ($censo) = grep { $_->{id} eq 'censo' } @{ $t->get_ok('/api/fontes')->tx->res->json };
  ok !exists $censo->{versao} && !exists $censo->{proprio}, 'base de terceiros sem versão própria';
};

subtest 'IVET do EduMaps (#489): versão citável' => sub {
  my ($i) = grep { $_->{id} eq 'ivet_edumaps' } @{ $t->get_ok('/api/fontes')->tx->res->json };
  ok $i->{proprio}, 'marcada como própria';
  is $i->{versao}, $EduMaps::Model::Ivet::Versao::VERSAO, 'versão do registro do IVET';
  is [ map { $_->{versao} } @{ $i->{historico} } ],
    [ map { $_->{versao} } @EduMaps::Model::Ivet::Versao::HISTORICO ], 'histórico completo';
  like $i->{url}, qr{ajuda/gestor/ivet\.md}, 'link para a ajuda do IVET';
  is $i->{telas}, ['painel_escola'], 'usado no painel da escola';
  my ($calc) = $dbh->selectrow_array(q{SELECT to_char(max(calculado_em) AT TIME ZONE 'America/Sao_Paulo', 'YYYY-MM-DD') FROM analytics.ivet_escola});
  is $i->{carga} ? $i->{carga}{data} : undef, $calc, 'carga = último cálculo do painel';
  ok !exists $i->{versao_de}, 'campo interno não vaza';
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
  for my $f (grep { !$_->{proprio} } @$r) {
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
