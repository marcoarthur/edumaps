use lib qw(t/lib lib);
use Imports;
use EduMaps::Data::Allowlist;
use File::Temp qw(tempdir);
use File::Spec;

# Testes sobre o ARQUIVO REAL data_pipeline/allowlist.yaml (issue #230).
# O allowlist.t usa um YAML sintético e passou enquanto o arquivo real tinha
# `sources:` e `denied:` duplicados (8 fontes sumidas, `denied` vazio).

my $real = '../data_pipeline/allowlist.yaml';
plan skip_all => "rodar a partir de backend/ ($real não encontrado)" unless -f $real;

my $al = EduMaps::Data::Allowlist->new(file_path => $real);

subtest 'arquivo real carrega com todas as fontes e regras' => sub {
    my @ids = map { $_->{id} } $al->sources->@*;
    is(scalar @ids, 24, '24 fontes (22 ativas + 2 inativas)') or diag "@ids";

    my @ativas = grep { lc($_->{status} // 'ativo') ne 'inativo' } $al->sources->@*;
    is(scalar @ativas, 22, '22 fontes ativas');

    # As 8 fontes que sumiam com o bloco `sources:` duplicado
    my %have = map { $_ => 1 } @ids;
    ok($have{$_}, "fonte $_ presente")
        for qw(fnde_siope_remuneracao ibge_sidra ibge_servicodados inmet mapbiomas
               ibge_geoftp tesouror_siconfi cgu_transparencia);
    # ... e as do antigo 2º bloco
    ok($have{$_}, "fonte $_ presente")
        for qw(datasus_sisab cnes_estabelecimentos brazilcrime antt_acidentes
               transportes_renatest transportes_renavam osrm_valhalla overpass_osm
               inep mec_nicbr fnde secretarias_educacao);

    is([ sort map { $_->{id} } $al->denied->@* ],
       [ sort qw(antta_monitriip_viagens sptrans_bilhete_unico_usuario
                 sus_sisvan_individual sus_vacinacao_individual sus_cnes_individual) ],
       'as 5 regras de LGPD estão ativas em denied');

    is(scalar $al->sources_r->@*, 3, 'sources_ref preservado (3)');
};

subtest 'URLs de LGPD são NEGADAS (não só "fora da allowlist")' => sub {
    my %urls = (
        antta_monitriip_viagens       => 'https://dados.antt.gov.br/dataset/monitriip-viagens',
        sptrans_bilhete_unico_usuario => 'https://dados.mobilidade.rio/dataset/creditos-eletronicos-bilhete-unico-usuario',
        sus_sisvan_individual         => 'https://dados.saude.gov.br/sisvan/estado-nutricional?uf=SP',
        sus_vacinacao_individual      => 'https://dados.saude.gov.br/vacinacao/doses-aplicadas-pni-2024/SP.csv',
        sus_cnes_individual           => 'https://dados.saude.gov.br/cnes/estabelecimentos',
    );
    my %reason = map { $_->{id} => $_->{reason} } $al->denied->@*;

    for my $id (sort keys %urls) {
        ok(!$al->validate_url($urls{$id}), "$id rejeitada");
        like($al->last_error, qr/explicitamente NEGADO/, "$id: motivo NEGADO");
        like($al->last_error, qr/\Q$reason{$id}\E/, "$id: cita a razão da regra");
    }
};

subtest 'fontes vivas aceitas' => sub {
    ok($al->validate_url($_), $_) or diag $al->last_error for (
        'https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do?acao=excel&cod_uf=35&municipios=355030&anos=2023&mes=0',
        'https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt/rreo?an_exercicio=2023&id_ente=35',
        'https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt/dca?an_exercicio=2023&id_ente=3550308',
        'https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt/entes',
        'https://apisidra.ibge.gov.br/values/t/5938/n6/3550308/v/37/p/2021?formato=json',
        'https://apisidra.ibge.gov.br/values/t/1393/n1/all/v/all/p/all/c11255/all',
        'https://portaldatransparencia.gov.br/download-de-dados/transferencias/202401',
        'https://dadosabertos-download.cgu.gov.br/PortalDaTransparencia/saida/transferencias/202401_Transferencias.zip',
        'https://storage.googleapis.com/mapbiomas-public/initiatives/brasil/collection11/lulc/coverage/brazil_coverage/brazil_coverage-col11_2025.tif',
        'https://download.inep.gov.br/microdados_censo_escolar_2023.zip',
        'https://overpass-api.de/api/interpreter',
    );

    is($al->get_resource_info('https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt/dca')->{source_id},
       'siconfi_apidatalake', 'apidatalake resolve para siconfi_apidatalake');
};

subtest 'hosts mortos e fora do escopo rejeitados' => sub {
    for my $url (
        'https://tesouror.transparencia.gov.br/api/v1/receitas?exercicio=2023',
        'https://dados.inmet.gov.br/alertas/cap12',
    ) {
        ok(!$al->validate_url($url), "$url rejeitada");
        like($al->last_error, qr/INATIVA/, 'motivo: fonte inativa');
        is($al->get_resource_info($url), undef, 'sem resource_info de fonte inativa');
    }

    ok(!$al->validate_url('https://storage.googleapis.com/outro-bucket/arquivo.tif'),
       'storage.googleapis.com fora do bucket mapbiomas-public rejeitado');
    ok(!$al->validate_url('https://download.inep.gov.br/microdados_censo_escolar_2023xzip'),
       '"." do path é literal (não casa qualquer caractere)');
};

subtest 'URL montada pela task SIOPE (Gastos.pm) passa' => sub {
    require EduMaps::Task::Siope::Scrap::SpreadSheet::Gastos;
    my $g = EduMaps::Task::Siope::Scrap::SpreadSheet::Gastos->new(
        cod_mun => 355030, ano => 2023, captcha => 'captcha-de-teste');
    # Reproduz get_data_p: base + query(_data), validado com o source_id usado lá
    my $url = $g->base->clone->query(%{ $g->_data });
    ok(EduMaps::Data::Allowlist->new(file_path => $real)
         ->validate_url($url, 'fnde_siope_remuneracao'), "SIOPE aceito: $url");
};

subtest 'estrutura inválida falha alto' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $n = 0;
    my $write = sub ($yaml) {
        my $f = File::Spec->catfile($dir, 'al' . $n++ . '.yaml');
        open my $fh, '>:encoding(UTF-8)', $f or die $!;
        print $fh $yaml;
        close $fh;
        return $f;
    };
    my $loads = sub ($f) { EduMaps::Data::Allowlist->new(file_path => $f)->sources };

    my $src = "  - id: a\n    host: a.gov.br\n    resources:\n      - path: /x\n";
    my $den = "  - id: d\n    host: a.gov.br\n    path: /y\n    reason: r\n";

    like(dies { $loads->($write->("sources:\n$src\ndenied:\n$den\nsources:\n  - id: b\n    host: b.gov.br\n")) },
         qr/chave de topo 'sources' duplicada \(linhas 1 e \d+\)/, 'sources: duplicado → die');
    like(dies { $loads->($write->("sources:\n$src\ndenied:\n$den\ndenied:\n")) },
         qr/chave de topo 'denied' duplicada/, 'denied: duplicado → die');
    like(dies { $loads->($write->("sources:\n$src$src\ndenied:\n$den")) },
         qr/id de fonte duplicado: 'a'/, 'id de fonte repetido → die');
    like(dies { $loads->($write->("sources:\n$src\ndenied:\n")) },
         qr/'denied' tem de ser uma lista/, 'denied vazio (não lista) → die');
    like(dies { $loads->($write->("sources:\n  id: a\ndenied:\n$den")) },
         qr/'sources' tem de ser uma lista/, 'sources como mapa → die');
    like(dies { $loads->($write->("denied:\n$den")) },
         qr/chave de topo 'sources' ausente/, 'sem sources → die');
    like(dies { $loads->(File::Spec->catfile($dir, 'nao-existe.yaml')) },
         qr/não encontrado/, 'arquivo inexistente → die');

    ok(lives { $loads->($write->("# sources: comentário não conta\nsources:\n$src\ndenied:\n$den")) },
       'arquivo válido carrega');
};

done_testing;
