use lib qw(t/lib lib);
use Imports;
use EduMaps::Data::Allowlist;
use File::Temp qw(tempdir);
use File::Spec;
use Encode qw(encode_utf8);

# Create a temporary allowlist for testing
my $tmpdir = tempdir(CLEANUP => 1);
my $allowlist_file = File::Spec->catfile($tmpdir, 'allowlist.yaml');

my $yaml_content = <<'YAML';
sources:
  - id: fnde_siope_remuneracao
    name: "FNDE SIOPE - Remuneração Municipal"
    host: www.fnde.gov.br
    base_url: "https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do"
    resources:
      - path: "/siope/consultarRemuneracaoMunicipal.do"
        method: GET
        description: "Planilha agregada"
        license: "Não verificada"

  - id: ibge_sidra
    name: "IBGE SIDRA"
    host: apisidra.ibge.gov.br
    resources:
      - path: "/values/t/1393/n1/all/v/all/p/all/c11255/all"
        method: GET
        description: "PIB municipal"
        license: "Domínio público"

denied:
  - id: sptrans_bilhete_unico_usuario
    source_ref: sptrans
    host: dados.mobilidade.rio
    path: "/dataset/creditos-eletronicos-bilhete-unico-usuario"
    reason: "Nível individual - LGPD"
YAML

# Write as UTF-8
open my $fh, '>:encoding(UTF-8)', $allowlist_file or die "Cannot write $allowlist_file: $!";
print $fh $yaml_content;
close $fh;

subtest 'allowlist carrega do arquivo' => sub {
    my $al = EduMaps::Data::Allowlist->new(file_path => $allowlist_file);
    ok($al, 'objeto criado');
    ok(scalar(@{$al->sources}) == 2, '2 fontes carregadas');
    ok(scalar(@{$al->denied}) == 1, '1 recurso negado carregado');
};

subtest 'URL permitida passa na validacao' => sub {
    my $al = EduMaps::Data::Allowlist->new(file_path => $allowlist_file);
    
    ok($al->validate_url('https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do?acao=excel&cod_uf=35&municipios=355030&anos=2023'),
       'URL FNDE SIOPE permitida');
    
    ok($al->validate_url('https://apisidra.ibge.gov.br/values/t/1393/n1/all/v/all/p/all/c11255/all'),
       'URL IBGE SIDRA permitida');
};

subtest 'URL com host permitido mas path nao listado e rejeitada' => sub {
    my $al = EduMaps::Data::Allowlist->new(file_path => $allowlist_file);
    
    ok(!$al->validate_url('https://www.fnde.gov.br/outro-endpoint'),
       'Path nao listado no mesmo host e rejeitado');
    # Apenas verifica que last_error nao e vazio
    ok(length($al->last_error) > 0, 'last_error nao vazio');
};

subtest 'Recurso explicitamente negado e rejeitado' => sub {
    my $al = EduMaps::Data::Allowlist->new(file_path => $allowlist_file);
    
    ok(!$al->validate_url('https://dados.mobilidade.rio/dataset/creditos-eletronicos-bilhete-unico-usuario'),
       'Recurso negado explicitamente e rejeitado');
    like($al->last_error, qr/NEGADO/);
};

subtest 'Host nao listado e rejeitado' => sub {
    my $al = EduMaps::Data::Allowlist->new(file_path => $allowlist_file);
    
    ok(!$al->validate_url('https://site-desconhecido.com/api'),
       'Host desconhecido e rejeitado');
    ok(length($al->last_error) > 0, 'last_error nao vazio');
};

subtest 'get_license_for_url retorna licenca' => sub {
    my $al = EduMaps::Data::Allowlist->new(file_path => $allowlist_file);
    
    my $license = $al->get_license_for_url('https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do');
    is($license, 'Não verificada', 'Licenca do FNDE');
    
    $license = $al->get_license_for_url('https://apisidra.ibge.gov.br/values/t/1393/n1/all/v/all/p/all/c11255/all');
    is($license, 'Domínio público', 'Licenca do IBGE');
    
    $license = $al->get_license_for_url('https://desconhecido.com');
    is($license, 'Não verificada', 'Desconhecido retorna Não verificada');
};

subtest 'validate_url com source_id restringe a aquela fonte' => sub {
    my $al = EduMaps::Data::Allowlist->new(file_path => $allowlist_file);
    
    ok($al->validate_url('https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do', 'fnde_siope_remuneracao'),
       'FNDE valido com source_id correto');
    
    ok(!$al->validate_url('https://apisidra.ibge.gov.br/values/t/1393/n1/all/v/all/p/all/c11255/all', 'fnde_siope_remuneracao'),
       'IBGE rejeitado quando source_id e FNDE');
};

subtest 'get_resource_info retorna metadados' => sub {
    my $al = EduMaps::Data::Allowlist->new(file_path => $allowlist_file);
    
    my $info = $al->get_resource_info('https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do');
    ok($info, 'info retornado');
    is($info->{source_id}, 'fnde_siope_remuneracao');
    is($info->{resource}{license}, 'Não verificada');
};

done_testing;