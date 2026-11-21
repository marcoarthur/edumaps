package EduMaps::Roles::Business::School::Profile;
use Mojo::Base -role, -signatures;
use DateTime;
use Mojo::Collection qw(c);
use EduMaps::Model::Rank::School;
use EduMaps::Model::Domain::SchoolQuality;
use EduMaps::Task::SchoolEmbedding ();
use Carp qw(croak);

requires qw(schema default_columns);

with 'EduMaps::Model::Role::CensoLabels';   # rótulos canônicos (issue #228)

has rank_model => sub ($self) {
  EduMaps::Model::Rank::School->new({ schema => $self->schema });
};


has default_date => sub {
  DateTime->new( day => 1, month => 6, year => 2025 )
};

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

        # Inclusão (educação especial — alunos com deficiência)
        esp_cc_total => $mat->qt_mat_esp_cc // 0,
        esp_ce_total => $mat->qt_mat_esp_ce // 0,

        # Turno (as colunas qt_mat_*_d/dm/dv/n são Diurno/Matutino/Vespertino/Noturno)
        turno => {
          diurno     => $mat->qt_mat_bas_d // 0,
          matutino   => $mat->qt_mat_bas_dm // 0,
          vespertino => $mat->qt_mat_bas_dv // 0,
          noturno    => $mat->qt_mat_bas_n // 0,
          integral   => $mat->qt_mat_bas_int // 0,
        },

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
  # #510 (RA-02): as matrículas são o total da educação básica do Censo
  # (qt_mat_bas), que já contém a infantil, a EJA e o médio. Antes o painel
  # somava as três de novo (Amai Pro: 357 no lugar de 285). Sempre o Censo
  # mais recente, dito na resposta (ano_censo).
  my ($ano_censo) = $self->schema->storage->dbh->selectrow_array(
    'SELECT max(nu_ano_censo) FROM clean.censo_escolas');
  my $school = $rs->search_rs(
    { 'me.co_entidade' => $params->{cod_inep},
      (defined $ano_censo ? ('me.nu_ano_censo' => $ano_censo) : ()) },
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

  # Similaridade via pgvector (índice HNSW, distância euclidiana entre as seis
  # notas, #487): top-k calculado no banco, sem trazer todas as escolas do
  # município para o Perl. Se a tabela/embedding não estiver disponível
  # (deploy parcial), cai no método antigo em memória, que não manda a
  # distância (é outra métrica).
  my $mat = $self->schema->resultset('CensoMatriculas');
  # Escola sem linha de matrículas no Censo (ex.: centro de atendimento
  # especializado) fica sem o número, em vez de derrubar o painel (500).
  my $attach_matriculas = sub ($record) {
    my $m = $mat->search_rs(
      { co_entidade => $record->{co_entidade},
        (defined $ano_censo ? (nu_ano_censo => $ano_censo) : ()) },
      { columns => [ {matriculas => 'qt_mat_bas'} ] },
    )->as_hash->first;
    $record->{matriculas} = $m ? $m->{matriculas} : undef;
    return $record;
  };
  $attach_matriculas->($school);

  my $neighbors = eval {
    $self->schema->resultset('SchoolEmbedding')
      ->similar_to($school->{co_entidade}, 3, $school->{co_municipio});
  };

  my $similars;
  my $similars_motivo;

  # Escola sem alguma das 6 notas fica fora do embedding (#413, #154): sem
  # vizinhas, e o painel diz que falta dado, em vez de cair calado no método
  # antigo. Erro de banco (tabela ausente) segue caindo no método antigo.
  my $sem_dado = $neighbors && !@$neighbors && !eval {
    EduMaps::Task::SchoolEmbedding::notas_completas($self->schema->storage->dbh, $school->{co_entidade});
  };

  if ($sem_dado) {
    $similars        = c();
    $similars_motivo = 'sem_dado';
  }
  elsif ($neighbors && @$neighbors) {
    my %vizinha = map { $_->{co_entidade} => $_ } @$neighbors;
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
        my $n = $vizinha{$_};
        +{
          record    => $record,
          distance  => $n->{distance},
          # #487 (RL-02): quanto a vizinha se parece, em pontos, e nota a nota
          distancia => _arred($n->{distance}, 2),
          notas     => _notas_comparadas($n->{notas}, $n->{notas_alvo}),
        };
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
      rede => $self->censo_labels->rede_label($school->{tp_dependencia}),
      etapas => panel_etapas($school),
      infraestrutura => panel_infraestrutura($school),
      matriculas => $school->{matriculas},
      ano_censo => $school->{nu_ano_censo},
      latitude => $school->{latitude},
      longitude => $school->{longitude},
    },
    indicators => \%values,
    similar_schools => $similars->to_array,
    similar_schools_motivo => $similars_motivo,
    desempenho => $desempenho,
  };
}

# #510 (RA-01): etapas e infraestrutura do painel, com as MESMAS chaves da
# tela (ETAPAS_ORDER e INFRA_ORDER de frontend/.../icons/icon-data.js;
# t/06-tools/painel_chaves.t confere) e o estado de cada item:
#   1 = tem/oferece, 0 = não tem, undef = sem dado no Censo (n/d, #154).
# Antes a resposta era a lista do que estava aceso, com nomes que a tela não
# conhecia (pre_infantil, quadra_esporte) e sem a acessibilidade: o painel
# apagava a pré-escola, a quadra e as rampas de toda escola.
our @PANEL_ETAPAS = (
  [creche             => 'in_comum_creche'],
  [pre_escola         => 'in_comum_pre'],
  [fundamental_i      => 'in_comum_fund_ai'],
  [fundamental_ii     => 'in_comum_fund_af'],
  [ensino_medio       => 'in_comum_medio_medio'],
  [eja                => 'in_eja'],
  [profissionalizante => 'in_profissionalizante'],
);

# Itens de presença simples (1 = tem). Esgoto e energia ficam à parte.
our @PANEL_INFRA = (
  [agua_potavel            => 'in_agua_potavel'],
  [coleta_lixo             => 'in_lixo_servico_coleta'],
  [internet                => 'in_internet'],
  [biblioteca              => 'in_biblioteca'],
  [laboratorio_ciencias    => 'in_laboratorio_ciencias'],
  [laboratorio_informatica => 'in_laboratorio_informatica'],
  [quadra_esportes         => 'in_quadra_esportes'],
  # mesma coluna da base de análise (in_acessibilidade_rampas)
  [acessibilidade          => 'in_acessibilidade_rampas'],
  [alimentacao             => 'in_alimentacao'],
);

sub _flag ($v) { defined $v ? ($v ? 1 : 0) : undef }

sub panel_etapas ($censo) {
  return { map { $_->[0] => _flag($censo->{ $_->[1] }) } @PANEL_ETAPAS };
}

# Esgoto e energia (#510, RA-01): tem quando não é "inexistente", como na base
# de análise e no ranking de escolas; a fossa ou o gerador não são falta. O
# detalhe diz se é a rede pública ou outra solução.
sub _servico ($censo, $rede, $inexistente) {
  my $nao_tem = $censo->{$inexistente};
  return { tem => undef, detalhe => undef } unless defined $nao_tem;
  return { tem => 0, detalhe => undef } if $nao_tem;
  return { tem => 1, detalhe => ($censo->{$rede} ? 'rede_publica' : 'outra_solucao') };
}

sub panel_infraestrutura ($censo) {
  my %infra = map { $_->[0] => _flag($censo->{ $_->[1] }) } @PANEL_INFRA;
  my %detalhe;
  for my $s ([energia => 'in_energia_rede_publica', 'in_energia_inexistente'],
             [esgoto  => 'in_esgoto_rede_publica',  'in_esgoto_inexistente']) {
    my $r = _servico($censo, $s->[1], $s->[2]);
    $infra{ $s->[0] } = $r->{tem};
    $detalhe{ $s->[0] } = $r->{detalhe} if $r->{detalhe};
  }
  $infra{detalhe} = \%detalhe;
  return \%infra;
}

# #487: rótulos curtos das seis notas do embedding, na ordem de
# EduMaps::Task::SchoolEmbedding::@NOTAS.
our %NOTA_ROTULO = (
  score_capacidade_atendimento => 'Atendimento',
  score_infraestrutura         => 'Infraestrutura',
  score_capacitacao_docente    => 'Docência',
  score_diversidade_discente   => 'Diversidade',
  score_capacidade_gestora     => 'Gestão',
  score_sustentabilidade       => 'Sustentabilidade',
);

sub _arred ($v, $casas) {
  return undef unless defined $v;
  return 0 + sprintf("%.${casas}f", $v);
}

# Notas da vizinha ao lado das da escola: [{ id, rotulo, valor, escola }].
sub _notas_comparadas ($vizinha, $alvo) {
  return [] unless ref $vizinha eq 'ARRAY' && ref $alvo eq 'ARRAY';
  my @ids = @EduMaps::Task::SchoolEmbedding::NOTAS;
  return [ map {
    +{
      id     => $ids[$_],
      rotulo => $NOTA_ROTULO{ $ids[$_] },
      valor  => _arred($vizinha->[$_], 2),
      escola => _arred($alvo->[$_], 2),
    }
  } 0 .. $#ids ];
}

1;
