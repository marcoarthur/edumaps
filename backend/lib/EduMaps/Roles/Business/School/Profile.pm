package EduMaps::Roles::Business::School::Profile;
use Mojo::Base -role, -signatures;
use DateTime;
use Mojo::Collection qw(c);
use EduMaps::Model::Rank::School;
use EduMaps::Model::Domain::SchoolQuality;
use Carp qw(croak);

requires qw(schema default_columns);

has rank_model => sub ($self) {
  EduMaps::Model::Rank::School->new({ schema => $self->schema });
};


has default_date => sub {
  DateTime->new( day => 1, month => 6, year => 2025 )
};

our %adm_labels = (
  1 => 'Federal',
  2 => 'Estadual',
  3 => 'Municipal',
  4 => 'Privada',
);

sub info($self, $params = {}) {

  return $self->schema->resultset('Escolas')
  ->search_rs({codigo_inep => $params->{codigo_inep}})
  ->columns($self->default_columns)
  ->as_hash->first;
}

# Deprecated grades -> use info_grades() instead
sub grades($self, $params = {}) {
  my $notas = $self->schema->resultset('InepNotasDesagregadas');
  $self->set_params_map(
    params => $params,
    map => {
      id_escola => [qw/cod_inep inep/],
      ano => [
        [[qw(since)],[qw(until)]],
        sub ($since, $until = DateTime->now->year) { return {-between => [$since, $until]} }
      ],
    }
  );

  my $columns = [
    'ano',
    { portugues => \q{round(nota_por/50, 2)} },
    { matematica => \q{round(nota_mat/50, 2)} },
    { media => \q{nota_media} },
  ];

  my $grades = $notas->search_rs($params)->columns($columns)->as_hash->get_all->each(
    sub {$self->_format_float_nums($_)}
  );
  return $grades->to_array;
}

# New grades
sub info_grades($self, $params = {}) {
  my $notas = $self->schema->resultset('IdebNotasEscolas');
  $params->{ano}   //= $self->default_date->year;
  $params->{etapa} //= [qw/fundamental_i fundamental_ii ensino_medio/];

  croak "Need school id/ids" unless $params->{id_escola};
  return $notas->search_rs($params)->as_hash->get_all;
}

sub info_enrollment($self, $params = {}) {
  my $rs = $self->schema->resultset('CensoEscolas');
  my $alias = $rs->current_source_alias;

  $params->{"$alias.nu_ano_censo"} //= $self->default_date->year;

  croak "Need school id/ids" unless my ($key) = grep {/co_entidade/} keys %$params;
  # put $alias prefix if not present
  my $new_key = index($key, $alias) != 0 ? "${alias}." . $key : $key;
  my $new_param = { $new_key => $params->{$key} };

  my $results = $rs->search_rs($new_param)
  ->search_related('matricula')->get_all;

  return $results->map(
    sub {
      my $mat = $_;
      return {
        # Totais principais
        total_basica => $mat->qt_mat_bas // 0,
        infantil     => $mat->qt_mat_inf // 0,
        fundamental  => $mat->qt_mat_fund // 0,
        medio        => $mat->qt_mat_med // 0,
        profissional => $mat->qt_mat_prof // 0,
        eja          => $mat->qt_mat_eja // 0,
        especial     => $mat->qt_mat_esp // 0,

        # Desagregação fundamental
        fundamental_ai => $mat->qt_mat_fund_ai // 0,
        fundamental_af => $mat->qt_mat_fund_af // 0,

        # Inclusão (alunos com deficiência)
        deficiencia_basica => ($mat->qt_mat_bas_d // 0) +
        ($mat->qt_mat_bas_dm // 0) +
        ($mat->qt_mat_bas_dv // 0),

        # Alunos com deficiência em classes comuns vs exclusivas
        esp_cc_total => $mat->qt_mat_esp_cc // 0,
        esp_ce_total => $mat->qt_mat_esp_ce // 0,

        # Demografia
        sexo => {
          feminino => $mat->qt_mat_bas_fem // 0,
          masculino => $mat->qt_mat_bas_masc // 0,
          nao_declarado => $mat->qt_mat_bas_nd // 0,
        },
        raca => {
          branca => $mat->qt_mat_bas_branca // 0,
          preta => $mat->qt_mat_bas_preta // 0,
          parda => $mat->qt_mat_bas_parda // 0,
          amarela => $mat->qt_mat_bas_amarela // 0,
          indigena => $mat->qt_mat_bas_indigena // 0,
        },
        idade => {
          '0-3'   => $mat->qt_mat_bas_0_3 // 0,
          '4-5'   => $mat->qt_mat_bas_4_5 // 0,
          '6-10'  => $mat->qt_mat_bas_6_10 // 0,
          '11-14' => $mat->qt_mat_bas_11_14 // 0,
          '15-17' => $mat->qt_mat_bas_15_17 // 0,
          '18+'   => $mat->qt_mat_bas_18_mais // 0,
        },

        # Integralidade e EAD
        integral => $mat->qt_mat_bas_int // 0,
        ead      => $mat->qt_mat_bas_ead // 0,

        # Localização
        localizacao => {
          urbana => $mat->qt_mat_zr_urb // 0,
          rural  => $mat->qt_mat_zr_rur // 0,
          nao_aplicavel => $mat->qt_mat_zr_na // 0,
        },

        # Transporte
        transporte_publico => $mat->qt_transp_publico // 0,
        transporte_estadual => $mat->qt_transp_resp_est // 0,
        transporte_municipal => $mat->qt_transp_resp_mun // 0,
      }
    }
  );
}

sub panel_info($self, $params) {
  my $rs = $self->schema->resultset('CensoEscolas');
  my $m = 'matricula'; #alias
  my @fields = qw/qt_mat_bas qt_mat_inf qt_mat_eja qt_mat_med/;
  my $school = $rs->join('matricula')->search_rs(
    { 'me.co_entidade' => $params->{cod_inep} },
    { '+columns' => 
      [
        {matriculas => \join('+', map {"$m.$_"} @fields)}
      ]
    },
  )->as_hash->first;

  return unless $school;

  my $rank = $self->rank_model;
  my $indicators = $rank->available_indicators($params->{cod_inep});
  my %values = map {
    $_->{id} => $rank->rank($params->{cod_inep}, $_->{id}, { fast => 1 });
  } grep { ${$_->{available}} == 1 } @$indicators;

  my $in_city = EduMaps::Model::Domain::SchoolQuality->new(
    {
      schema => $self->schema,
      geo_tag => $school->{co_municipio}
    }
  );

  # Similaridade via pgvector (índice HNSW, cosseno): top-k calculado no banco,
  # sem trazer todas as escolas do município para o Perl. Se a tabela/embedding
  # não estiver disponível (deploy parcial), cai no método antigo em memória.
  my $mat = $self->schema->resultset('CensoMatriculas');
  my $attach_matriculas = sub ($record) {
    $record->{matriculas} = $mat->search_rs(
      { co_entidade => $record->{co_entidade} },
      { columns => [ {matriculas => \join('+', @fields)} ] },
    )->as_hash->first->{matriculas};
    return $record;
  };

  my $neighbors = eval {
    $self->schema->resultset('SchoolEmbedding')
      ->similar_to($school->{co_entidade}, 3, $school->{co_municipio});
  };

  my $similars;

  if ($neighbors && @$neighbors) {
    my %distance = map { $_->{co_entidade} => $_->{distance} } @$neighbors;
    my @ids = map { $_->{co_entidade} } @$neighbors;

    my $records = $self->schema->resultset('CensoEscolas')
      ->search_rs({ 'me.co_entidade' => { -in => \@ids } })
      ->as_hash->get_all;
    my %by_id = map { $_->{co_entidade} => $_ } @$records;

    $similars = c(
      map {
        my $record = $by_id{$_};
        next unless $record;
        $attach_matriculas->($record);
        +{ record => $record, distance => $distance{$_} };
      } @ids
    );
  }
  else {
    $similars = $in_city->find_similar_schools($school, 3)->each(
      # inclui as matriculas nos dados do censo das escolas similares
      sub { $attach_matriculas->($_->{record}) }
    );
  }

  # Série histórica de desempenho (IDEB/SAEB por etapa e ano). Fonte única:
  # clean.ideb_notas_escolas — NÃO usar clean.inep / clean.inep_notas_desagregadas
  # (deprecated).
  my $desempenho = $self->schema->resultset('IdebNotasEscolas')
    ->search_rs({ id_escola => $school->{co_entidade} })
    ->order_by([{ -asc => 'etapa' }, { -asc => 'ano' }])
    ->as_hash->get_all->to_array;

  return {
    escola => {
      id_escola => $school->{co_entidade},
      nome => $school->{no_entidade},
      municipio => $school->{no_municipio},
      uf => $school->{no_uf},
      rede => $adm_labels{$school->{tp_dependencia}},
      etapas => $self->_etapas($school),
      infraestrutura => $self->_infraestrutura($school),
      matriculas => $school->{matriculas},
      latitude => $school->{latitude},
      longitude => $school->{longitude},
    },
    indicators => \%values,
    similar_schools => $similars->to_array,
    desempenho => $desempenho,
  };
}

sub _etapas($self, $censo) {
  my %fields = (
    creche => 'in_comum_creche',
    pre_infantil => 'in_comum_pre',
    fundamental_i => 'in_comum_fund_ai',
    fundamental_ii => 'in_comum_fund_af',
    ensino_medio => 'in_comum_medio_medio',
    profissionalizante => 'in_profissionalizante',
    eja_fundamental => 'in_comum_eja_fund',
    eja_medio => 'in_comum_eja_medio',
    eja => 'in_eja',
  );

  my @etapas = grep { $censo->{$fields{$_}} } keys %fields;
  return \@etapas;
}

sub _infraestrutura($self, $censo) {
  my %fields = (
    internet => 'in_internet',
    agua_potavel => 'in_agua_potavel',
    energia => 'in_energia_rede_publica',
    alimentacao => 'in_alimentacao',
    biblioteca => 'in_biblioteca',
    laboratorio_ciencias => 'in_laboratorio_ciencias',
    esgoto => 'in_esgoto_rede_publica',
    coleta_lixo => 'in_lixo_servico_coleta',
    laboratorio_informatica => 'in_laboratorio_informatica',
    quadra_esporte => 'in_quadra_esportes',
  );

  my @infra = grep { $censo->{$fields{$_}} } keys %fields;
  return \@infra;
}

1;
