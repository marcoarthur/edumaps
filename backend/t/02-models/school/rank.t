use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';
use utf8;

use ok 'EduMaps::Schema';
use ok 'EduMaps::Model::Rank::School';

sub show_structure {
  my ($data, $label) = @_;
  $label ||= 'Data';
  use Data::Dumper;
  local $Data::Dumper::Indent   = 1;
  local $Data::Dumper::Sortkeys = 1;
  local $Data::Dumper::Terse    = 0;
  diag "$label: " . Dumper($data);
  return;
}

my $schema = EduMaps::Schema->go;
my $model  = EduMaps::Model::Rank::School->new(schema => $schema);

# ============================================================================
# Buscar escolas de exemplo com dados adequados para os testes
# ============================================================================

# --- MV: escola com dados na rede municipal (tp_dependencia = 3) ---
my $mv_school_rs = $schema->resultset('MvEscolasScores')
->search_rs({ -and => [
      score_infraestrutura => { '!=' => undef },
      'me.co_entidade'     => { '!=' => undef },
    ] })
->join('escola')
->search_rs({ 'escola.tp_dependencia' => 3 })
->order_by({ -desc => 'nu_ano_censo' })
->limit(1);

my $mv_school = $mv_school_rs->first;
ok($mv_school, 'Encontrou escola com dados MV e rede municipal') or BAIL_OUT('Sem dados de MV municipal');
my $mv_cod_inep = $mv_school->co_entidade;

# --- Ideb: escola com dados para fundamental_ii (ideb_anos_finais) ---
my $ideb_school_rs = $schema->resultset('IdebNotasEscolas')
->search_rs(
  { 
    -and => [
      ideb_observado => { '!=' => undef },
      etapa          => 'fundamental_ii',
      id_escola      => { '!=' => undef },
    ] 
  }
)
->order_by({ -desc => 'ano' })
->limit(1);

my $ideb_school = $ideb_school_rs->first;
ok($ideb_school, 'Encontrou escola com dados Ideb (fundamental_ii)') or BAIL_OUT('Sem dados de Ideb para fundamental_ii');
my $ideb_cod_inep = $ideb_school->id_escola;

# ----------------------------------------------------------------------------
subtest 'available_indicators' => sub {
  my @scenarios = (
    { desc => 'com dados MV',   cod_inep => $mv_cod_inep },
    { desc => 'com dados Ideb', cod_inep => $ideb_cod_inep },
  );

  for my $case (@scenarios) {
    my $indicators = $model->available_indicators($case->{cod_inep});
    ok(ref $indicators eq 'ARRAY', "available_indicators retorna arrayref para $case->{desc}");

    my $first = $indicators->[0];
    like(
      $first,
      hash {
        field id         => qr/\w+/;
        field label      => qr/.+/;
        field available  => D();
        etc();
      },
      "Estrutura de cada indicador para $case->{desc}"
    );

    my $any_available = grep { $_->{available} } @$indicators;
    ok($any_available, "Pelo menos um indicador disponível para $case->{desc}");
  }
};

# ----------------------------------------------------------------------------
subtest 'rank - indicadores MV' => sub {
  my $indicator_id = 'infraestrutura';

  subtest 'sem filtro de rede' => sub {
    my $result = $model->rank($mv_cod_inep, $indicator_id);
    ok($result, 'rank retornou resultado');

    like(
      $result,
      hash {
        field indicador => hash {
          field id      => $indicator_id;
          field label   => 'Infraestrutura';
          field valor   => number_gt(0);
          etc();
        };
        field ano    => number_gt(2000);
        field rede   => undef;
        field ranking => hash {
          field municipio => hash {
            field posicao   => number_gt(0);
            field total     => number_gt(0);
            field percentil => number_gt(0);
            etc();
          };
          field estado => hash {
            field posicao   => number_gt(0);
            field total     => number_gt(0);
            field percentil => number_gt(0);
            etc();
          };
          field nacional => undef;
          etc();
        };
        etc();
      },
      'Estrutura do ranking MV sem filtros'
    );
  };

  subtest 'com filtro de rede (municipal)' => sub {
    my $result = $model->rank($mv_cod_inep, $indicator_id, { network => 'municipal' });
    show_structure($result, 'rank com rede municipal') unless $result;
    ok($result, 'rank com rede municipal retornou resultado');

    if ($result) {
      is($result->{rede}, 'municipal', 'rede retornada é municipal');
      ok(exists $result->{ranking}->{municipio}, 'ranking municipal presente');
    }
  };
};

# ----------------------------------------------------------------------------
subtest 'rank - indicadores Ideb' => sub {
  my $indicator_id = 'ideb_anos_finais';

  subtest 'sem filtro de rede' => sub {
    my $result = $model->rank($ideb_cod_inep, $indicator_id);
    show_structure($result, 'rank sem filtro Ideb') unless $result;
    ok($result, 'rank retornou resultado');

    if ($result) {
      like(
        $result,
        hash {
          field indicador => hash {
            field id      => $indicator_id;
            field label   => 'IDEB – Anos Finais';
            field valor   => number_gt(0);
            etc();
          };
          field ano    => number_gt(0);
          field rede   => undef;
          field ranking => hash {
            field municipio => hash {
              field posicao   => number_gt(0);
              field total     => number_gt(0);
              field percentil => number_gt(0);
              etc();
            };
            field estado => hash {
              field posicao   => number_gt(0);
              field total     => number_gt(0);
              field percentil => number_gt(0);
              etc();
            };
            field nacional => undef;
            etc();
          };
          etc();
        },
        'Estrutura do ranking Ideb sem filtros'
      );
    }
  };

  subtest 'com filtro de rede (estadual)' => sub {
    my $result = $model->rank($ideb_cod_inep, $indicator_id, { network => 'estadual' });
    show_structure($result, 'rank com rede estadual Ideb') unless $result;
    ok($result, 'rank com rede estadual retornou resultado');
    if ($result) {
      is($result->{rede}, 'estadual', 'rede retornada é estadual');
    }
  };

  subtest 'com filtro nacional ativado' => sub {
    my $result = $model->rank($ideb_cod_inep, $indicator_id, { national => 1 });
    show_structure($result, 'rank com national Ideb') unless $result;
    ok($result, 'rank com national ativado retornou resultado');
    if ($result) {
      ok(exists $result->{ranking}->{nacional}, 'ranking nacional presente');
    }
  };
};

# ----------------------------------------------------------------------------
subtest 'rank - erros e casos extremos' => sub {
  subtest 'indicador desconhecido' => sub {
    eval { $model->rank($mv_cod_inep, 'indicador_inexistente') };
    like($@, qr/Indicador desconhecido/, 'croak com mensagem adequada');
  };

  subtest 'rede desconhecida' => sub {
    eval { $model->rank($mv_cod_inep, 'infraestrutura', { network => 'federal' }) };
    like($@, qr/Rede de ensino desconhecida/, 'croak com mensagem adequada');
  };

  subtest 'escola sem dados' => sub {
    my $result = $model->rank('00000000', 'infraestrutura');
    is($result, undef, 'retorna undef para escola sem dados');
  };

  subtest 'escola sem dados para o indicador específico' => sub {
    my $school_with_null = $schema->resultset('MvEscolasScores')
    ->search_rs({ score_infraestrutura => undef, co_entidade => { '!=' => undef } })
    ->limit(1)->first;
    SKIP: {
      skip 'Nenhuma escola com score_infraestrutura nulo encontrada', 1 unless $school_with_null;
      my $result = $model->rank($school_with_null->co_entidade, 'infraestrutura');
      is($result, undef, 'retorna undef quando o indicador não está disponível');
    }
  };
};

# ----------------------------------------------------------------------------
subtest 'rank - indicadores com diferentes fontes' => sub {
  my @mv_indicators   = grep { $_->{source} eq 'mv' } values %{ $model->indicator_registry };
  my @ideb_indicators = grep { $_->{source} eq 'ideb' } values %{ $model->indicator_registry };

  ok(scalar @mv_indicators > 0,   'Existem indicadores MV registrados');
  ok(scalar @ideb_indicators > 0, 'Existem indicadores Ideb registrados');

  my $mv_indicator   = $mv_indicators[0]->{id} // 'infraestrutura';
  my $ideb_indicator = $ideb_indicators[0]->{id} // 'ideb_anos_finais';

  for my $ind (($mv_indicator, $ideb_indicator)) {
    my $cod_inep = ($ind eq $mv_indicator) ? $mv_cod_inep : $ideb_cod_inep;
    my $result = $model->rank($cod_inep, $ind);
    show_structure($result, "rank para $ind") unless $result;
    ok($result, "rank para indicador $ind retornou resultado");
  }
};

done_testing;
