package EduMaps::Roles::Business::Gestor::Inventario;
use Mojo::Base -role, -signatures;
use Mojo::JSON ();
use utf8;

# Inventário escolar do gestor: recursos (bens) e serviços (contas/contratos)
# unificados em itens com categorias de nome livre, fornecedores e anexos.
#
# O Censo é somente LIDO (clean.censo_escolas): o baseline é derivado em tempo
# real (inventario_censo) e pode ser "importado" para itens manuais via
# censo_ref (idempotente). Nada novo é gravado nas tabelas do Censo.
#
# Técnica de flexibilidade: nenhuma coluna nova é necessária para criar uma
# categoria/item/serviço — categorias são livres e campos extras vão em
# atributos (JSONB).

requires qw(schema);

our $DEFAULT_YEAR = 2025;

our %EXT_MIME = (
  pdf  => 'application/pdf',
  docx => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  xlsx => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  png  => 'image/png',
  jpg  => 'image/jpeg',
  jpeg => 'image/jpeg',
  txt  => 'text/plain',
);

sub max_upload_bytes { return 10 * 1024 * 1024; }

sub ext_mime { return \%EXT_MIME; }

# ---------------------------------------------------------------------------
# taxonomia semeada do Censo (categorias iniciais, editáveis pelo gestor)
# ---------------------------------------------------------------------------

our %TAXONOMIA_TIPO = (
  'Computadores'                     => 'recurso',
  'Notebooks'                        => 'recurso',
  'Tablets'                          => 'recurso',
  'Impressoras e periféricos'        => 'recurso',
  'Equipamentos audiovisuais'        => 'recurso',
  'Materiais pedagógicos'            => 'recurso',
  'Espaços e salas'                  => 'recurso',
  'Infraestrutura e serviços básicos' => 'servico',
  'Conectividade'                    => 'servico',
);

# Grupos do baseline do Censo. Cada item: key, label, coluna `in`, `qty`
# opcional e a categoria de destino na importação.
our @CENSO_GRUPOS = (
  {
    key => 'dispositivos', label => 'Dispositivos', itens => [
      { key => 'desktop_aluno',  label => 'Computadores (aluno)', in => 'in_desktop_aluno',       qty => 'qt_desktop_aluno',       categoria => 'Computadores' },
      { key => 'notebook_aluno', label => 'Notebooks (aluno)',    in => 'in_comp_portatil_aluno', qty => 'qt_comp_portatil_aluno', categoria => 'Notebooks' },
      { key => 'tablet_aluno',   label => 'Tablets (aluno)',      in => 'in_tablet_aluno',        qty => 'qt_tablet_aluno',        categoria => 'Tablets' },
    ],
  },
  {
    key => 'equipamentos', label => 'Equipamentos', itens => [
      { key => 'computador',      label => 'Computador',                in => 'in_computador',            categoria => 'Computadores' },
      { key => 'impressora',      label => 'Impressora',                in => 'in_equip_impressora',      categoria => 'Impressoras e periféricos' },
      { key => 'impressora_mult', label => 'Impressora multifuncional', in => 'in_equip_impressora_mult', categoria => 'Impressoras e periféricos' },
      { key => 'copiadora',       label => 'Copiadora',                 in => 'in_equip_copiadora',       categoria => 'Impressoras e periféricos' },
      { key => 'scanner',         label => 'Scanner',                   in => 'in_equip_scanner',         categoria => 'Impressoras e periféricos' },
      { key => 'tv',              label => 'Televisão',                 in => 'in_equip_tv',              qty => 'qt_equip_tv',        categoria => 'Equipamentos audiovisuais' },
      { key => 'som',             label => 'Aparelho de som',           in => 'in_equip_som',             qty => 'qt_equip_som',       categoria => 'Equipamentos audiovisuais' },
      { key => 'dvd',             label => 'Aparelho de DVD',           in => 'in_equip_dvd',             qty => 'qt_equip_dvd',       categoria => 'Equipamentos audiovisuais' },
      { key => 'lousa_digital',   label => 'Lousa digital',             in => 'in_equip_lousa_digital',   qty => 'qt_equip_lousa_digital', categoria => 'Equipamentos audiovisuais' },
      { key => 'multimidia',      label => 'Projetor multimídia',       in => 'in_equip_multimidia',      qty => 'qt_equip_multimidia', categoria => 'Equipamentos audiovisuais' },
      { key => 'parabolica',      label => 'Antena parabólica',         in => 'in_equip_parabolica',      categoria => 'Equipamentos audiovisuais' },
    ],
  },
  {
    key => 'materiais', label => 'Materiais pedagógicos', itens => [
      { key => 'material_agricola',    label => 'Material pedagógico — agrícola',        in => 'in_material_ped_agricola',    categoria => 'Materiais pedagógicos' },
      { key => 'material_artisticas',  label => 'Material pedagógico — artísticas',      in => 'in_material_ped_artisticas',  categoria => 'Materiais pedagógicos' },
      { key => 'material_bil_surdos',  label => 'Material pedagógico — bilíngue de surdos', in => 'in_material_ped_bil_surdos', categoria => 'Materiais pedagógicos' },
      { key => 'material_campo',       label => 'Material pedagógico — educação do campo', in => 'in_material_ped_campo',      categoria => 'Materiais pedagógicos' },
      { key => 'material_cientifico',  label => 'Material pedagógico — científico',      in => 'in_material_ped_cientifico',  categoria => 'Materiais pedagógicos' },
      { key => 'material_desportiva',  label => 'Material pedagógico — desportiva',      in => 'in_material_ped_desportiva',  categoria => 'Materiais pedagógicos' },
      { key => 'material_difusao',     label => 'Material pedagógico — difusão',         in => 'in_material_ped_difusao',     categoria => 'Materiais pedagógicos' },
      { key => 'material_edu_esp',     label => 'Material pedagógico — educação especial', in => 'in_material_ped_edu_esp',   categoria => 'Materiais pedagógicos' },
      { key => 'material_etnico',      label => 'Material pedagógico — étnico-racial',   in => 'in_material_ped_etnico',      categoria => 'Materiais pedagógicos' },
      { key => 'material_indigena',    label => 'Material pedagógico — indígena',        in => 'in_material_ped_indigena',    categoria => 'Materiais pedagógicos' },
      { key => 'material_infantil',    label => 'Material pedagógico — infantil',        in => 'in_material_ped_infantil',    categoria => 'Materiais pedagógicos' },
      { key => 'material_jogos',       label => 'Material pedagógico — jogos',           in => 'in_material_ped_jogos',       categoria => 'Materiais pedagógicos' },
      { key => 'material_multimidia',  label => 'Material pedagógico — multimídia',      in => 'in_material_ped_multimidia',  categoria => 'Materiais pedagógicos' },
      { key => 'material_musical',     label => 'Material pedagógico — musical',         in => 'in_material_ped_musical',     categoria => 'Materiais pedagógicos' },
      { key => 'material_profissional', label => 'Material pedagógico — profissional',   in => 'in_material_ped_profissional', categoria => 'Materiais pedagógicos' },
      { key => 'material_quilombola',  label => 'Material pedagógico — quilombola',      in => 'in_material_ped_quilombola',  categoria => 'Materiais pedagógicos' },
    ],
  },
  {
    key => 'espacos', label => 'Espaços e salas', itens => [
      { key => 'biblioteca',              label => 'Biblioteca',                 in => 'in_biblioteca',              categoria => 'Espaços e salas' },
      { key => 'sala_leitura',            label => 'Sala de leitura',            in => 'in_biblioteca_sala_leitura', categoria => 'Espaços e salas' },
      { key => 'laboratorio_ciencias',    label => 'Laboratório de ciências',    in => 'in_laboratorio_ciencias',    categoria => 'Espaços e salas' },
      { key => 'laboratorio_informatica', label => 'Laboratório de informática', in => 'in_laboratorio_informatica', categoria => 'Espaços e salas' },
      { key => 'laboratorio_educ_prof',   label => 'Laboratório de educação profissional', in => 'in_laboratorio_educ_prof', categoria => 'Espaços e salas' },
      { key => 'quadra_esportes',         label => 'Quadra de esportes',         in => 'in_quadra_esportes',         categoria => 'Espaços e salas' },
      { key => 'quadra_coberta',          label => 'Quadra coberta',             in => 'in_quadra_esportes_coberta', categoria => 'Espaços e salas' },
      { key => 'patio_coberto',           label => 'Pátio coberto',              in => 'in_patio_coberto',           categoria => 'Espaços e salas' },
      { key => 'patio_descoberto',        label => 'Pátio descoberto',           in => 'in_patio_descoberto',        categoria => 'Espaços e salas' },
      { key => 'parque_infantil',         label => 'Parque infantil',            in => 'in_parque_infantil',         categoria => 'Espaços e salas' },
      { key => 'auditorio',               label => 'Auditório',                  in => 'in_auditorio',               categoria => 'Espaços e salas' },
      { key => 'sala_professor',          label => 'Sala dos professores',       in => 'in_sala_professor',          categoria => 'Espaços e salas' },
      { key => 'sala_diretoria',          label => 'Sala da direção',            in => 'in_sala_diretoria',          categoria => 'Espaços e salas' },
      { key => 'secretaria',              label => 'Secretaria',                 in => 'in_secretaria',              categoria => 'Espaços e salas' },
      { key => 'area_verde',              label => 'Área verde',                 in => 'in_area_verde',              categoria => 'Espaços e salas' },
      { key => 'sala_atelie_artes',       label => 'Sala de ateliê de artes',    in => 'in_sala_atelie_artes',       categoria => 'Espaços e salas' },
      { key => 'sala_multiuso',           label => 'Sala multiuso',              in => 'in_sala_multiuso',           categoria => 'Espaços e salas' },
      { key => 'sala_musica_coral',       label => 'Sala de música/coral',       in => 'in_sala_musica_coral',       categoria => 'Espaços e salas' },
      { key => 'sala_atendimento_especial', label => 'Sala de atendimento especial', in => 'in_sala_atendimento_especial', categoria => 'Espaços e salas' },
      { key => 'almoxarifado',            label => 'Almoxarifado',               in => 'in_almoxarifado',            categoria => 'Espaços e salas' },
      { key => 'despensa',                label => 'Despensa',                   in => 'in_despensa',                categoria => 'Espaços e salas' },
      { key => 'dormitorio_aluno',        label => 'Dormitório de aluno',        in => 'in_dormitorio_aluno',        categoria => 'Espaços e salas' },
      { key => 'salas_utilizadas',        label => 'Salas de aula utilizadas',   in => 'in_sala_utilizada_placeholder', qty => 'qt_salas_utilizadas',   categoria => 'Espaços e salas' },
      { key => 'salas_climatizadas',      label => 'Salas climatizadas',         in => 'in_sala_utilizada_placeholder', qty => 'qt_salas_utiliza_climatizadas', categoria => 'Espaços e salas' },
      { key => 'salas_acessiveis',        label => 'Salas acessíveis',           in => 'in_sala_utilizada_placeholder', qty => 'qt_salas_utilizadas_acessiveis', categoria => 'Espaços e salas' },
    ],
  },
  {
    key => 'servicos_basicos', label => 'Infraestrutura e serviços básicos', itens => [
      { key => 'agua_potavel',   label => 'Água potável',             in => 'in_agua_potavel',          categoria => 'Infraestrutura e serviços básicos' },
      { key => 'energia',        label => 'Energia da rede pública',  in => 'in_energia_rede_publica',  categoria => 'Infraestrutura e serviços básicos' },
      { key => 'esgoto',         label => 'Esgoto da rede pública',   in => 'in_esgoto_rede_publica',   categoria => 'Infraestrutura e serviços básicos' },
      { key => 'fossa_septica',  label => 'Fossa séptica',            in => 'in_esgoto_fossa_septica',  categoria => 'Infraestrutura e serviços básicos' },
      { key => 'coleta_lixo',    label => 'Coleta de lixo',           in => 'in_lixo_servico_coleta',   categoria => 'Infraestrutura e serviços básicos' },
      { key => 'banheiro',       label => 'Banheiro',                 in => 'in_banheiro',              categoria => 'Infraestrutura e serviços básicos' },
      { key => 'cozinha',        label => 'Cozinha',                  in => 'in_cozinha',               categoria => 'Infraestrutura e serviços básicos' },
      { key => 'refeitorio',     label => 'Refeitório',               in => 'in_refeitorio',            categoria => 'Infraestrutura e serviços básicos' },
    ],
  },
  {
    key => 'conectividade', label => 'Conectividade', itens => [
      { key => 'internet',               label => 'Internet',                         in => 'in_internet',                    categoria => 'Conectividade' },
      { key => 'internet_alunos',        label => 'Internet para alunos',             in => 'in_internet_alunos',             categoria => 'Conectividade' },
      { key => 'internet_administrativo', label => 'Internet administrativa',         in => 'in_internet_administrativo',     categoria => 'Conectividade' },
      { key => 'internet_aprendizagem',  label => 'Internet de aprendizagem',         in => 'in_internet_aprendizagem',       categoria => 'Conectividade' },
      { key => 'internet_comunidade',    label => 'Internet para a comunidade',       in => 'in_internet_comunidade',         categoria => 'Conectividade' },
      { key => 'banda_larga',            label => 'Banda larga',                      in => 'in_banda_larga',                 categoria => 'Conectividade' },
      { key => 'acesso_computador',      label => 'Acesso à internet por computador', in => 'in_acesso_internet_computador',  categoria => 'Conectividade' },
      { key => 'dispositivos_pessoais',  label => 'Internet em dispositivos pessoais', in => 'in_aces_internet_disp_pessoais', categoria => 'Conectividade' },
    ],
  },
);

# ---------------------------------------------------------------------------
# baseline do Censo (somente leitura)
# ---------------------------------------------------------------------------

sub inventario_censo ($self, $cod_inep, $ano = undef) {
  $ano //= $DEFAULT_YEAR;
  my @cols = ('co_entidade', 'nu_ano_censo', 'no_entidade', 'no_municipio', 'sg_uf');
  for my $g (@CENSO_GRUPOS) {
    for my $it (@{ $g->{itens} }) {
      push @cols, $it->{in} if $it->{in} !~ /_placeholder$/;
      push @cols, $it->{qty} if $it->{qty};
    }
  }
  my %seen;
  @cols = grep { !$seen{$_}++ } @cols;

  my $row = $self->schema->resultset('CensoEscolas')
    ->search_rs({ co_entidade => $cod_inep, nu_ano_censo => $ano })
    ->columns(\@cols)
    ->as_hash->first
    or return;

  my @grupos;
  for my $g (@CENSO_GRUPOS) {
    my @itens;
    for my $it (@{ $g->{itens} }) {
      my $presente = ($it->{in} !~ /_placeholder$/ && ($row->{ $it->{in} } // 0)) ? 1 : 0;
      my $qtd = $it->{qty} ? ($row->{ $it->{qty} } // 0) : ($presente ? 1 : 0);
      next unless $presente || $qtd;
      push @itens, {
        key        => $it->{key},
        label      => $it->{label},
        presente   => $presente,
        qtd        => $qtd + 0,
        categoria  => $it->{categoria},
      };
    }
    push @grupos, { key => $g->{key}, label => $g->{label}, itens => \@itens } if @itens;
  }

  return {
    ano    => $ano + 0,
    escola => {
      id_escola => $cod_inep + 0,
      nome      => $row->{no_entidade},
      municipio => $row->{no_municipio},
      uf        => $row->{sg_uf},
    },
    grupos => \@grupos,
  };
}

# ---------------------------------------------------------------------------
# categorias
# ---------------------------------------------------------------------------

sub list_categorias ($self, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT c.id, c.tipo, c.nome, c.origem,
            (SELECT COUNT(*) FROM clean.inventario_itens i WHERE i.categoria_id = c.id) AS n_itens
     FROM   clean.inventario_categorias c
     WHERE  c.cod_inep = ?
     ORDER  BY c.tipo, lower(c.nome)',
    $cod_inep + 0,
  );
  return [ map {
    { id => $_->{id} + 0, tipo => $_->{tipo}, nome => $_->{nome},
      origem => $_->{origem}, n_itens => $_->{n_itens} + 0 }
  } @$rows ];
}

sub create_categoria ($self, $cod_inep, $gestor_id, $params = {}) {
  my $row = $self->_row(
    'INSERT INTO clean.inventario_categorias (cod_inep, gestor_id, tipo, nome, origem)
     VALUES (?, ?, ?, ?, \'manual\')
     RETURNING id, tipo, nome, origem',
    $cod_inep + 0, $self->_gestor_bind($gestor_id), $params->{tipo}, $params->{nome},
  ) or return;
  return { id => $row->{id} + 0, tipo => $row->{tipo}, nome => $row->{nome},
           origem => $row->{origem}, n_itens => 0 };
}

sub update_categoria ($self, $id, $cod_inep, $params = {}) {
  my $row = $self->_row(
    'UPDATE clean.inventario_categorias
     SET    tipo = ?, nome = ?, updated_at = NOW()
     WHERE  id = ? AND cod_inep = ?
     RETURNING id, tipo, nome, origem',
    $params->{tipo}, $params->{nome}, $id + 0, $cod_inep + 0,
  ) or return;
  return { id => $row->{id} + 0, tipo => $row->{tipo}, nome => $row->{nome},
           origem => $row->{origem} };
}

sub delete_categoria ($self, $id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.inventario_categorias WHERE id = ? AND cod_inep = ? RETURNING id',
    $id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

sub sincronizar_categorias_censo ($self, $cod_inep) {
  my $ja_tem = $self->_row(
    'SELECT 1 FROM clean.inventario_categorias
     WHERE cod_inep = ? AND origem = \'censo\' LIMIT 1',
    $cod_inep + 0,
  );
  return [] if $ja_tem;

  $self->_txn(sub {
    for my $nome (keys %TAXONOMIA_TIPO) {
      $self->_row(
        'INSERT INTO clean.inventario_categorias (cod_inep, gestor_id, tipo, nome, origem)
         VALUES (?, NULL, ?, ?, \'censo\')
         ON CONFLICT DO NOTHING
         RETURNING id',
        $cod_inep + 0, $TAXONOMIA_TIPO{$nome}, $nome,
      );
    }
  });

  return [ sort keys %TAXONOMIA_TIPO ];
}

# ---------------------------------------------------------------------------
# fornecedores
# ---------------------------------------------------------------------------

sub list_fornecedores ($self, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT f.id, f.nome, f.tipo_servico, f.email, f.telefone, f.site,
            f.documento, f.observacoes, f.atributos, f.updated_at,
            (SELECT COUNT(*) FROM clean.inventario_itens i WHERE i.fornecedor_id = f.id) AS n_itens
     FROM   clean.inventario_fornecedores f
     WHERE  f.cod_inep = ?
     ORDER  BY lower(f.nome)',
    $cod_inep + 0,
  );
  return [ map { $self->_fornecedor_out($_) } @$rows ];
}

sub create_fornecedor ($self, $cod_inep, $gestor_id, $params = {}) {
  my $row = $self->_row(
    'INSERT INTO clean.inventario_fornecedores
       (cod_inep, gestor_id, nome, tipo_servico, email, telefone, site, documento, observacoes, atributos)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb)
     RETURNING id',
    $cod_inep + 0, $self->_gestor_bind($gestor_id),
    $params->{nome}, $params->{tipo_servico}, $params->{email},
    $params->{telefone}, $params->{site}, $params->{documento},
    $params->{observacoes}, $self->_encode_atributos($params->{atributos}),
  ) or return;
  return $self->_fornecedor_detail($row->{id}, $cod_inep);
}

sub update_fornecedor ($self, $id, $cod_inep, $params = {}) {
  my $row = $self->_row(
    'UPDATE clean.inventario_fornecedores
     SET    nome = ?, tipo_servico = ?, email = ?, telefone = ?, site = ?,
            documento = ?, observacoes = ?, atributos = ?::jsonb, updated_at = NOW()
     WHERE  id = ? AND cod_inep = ?
     RETURNING id',
    $params->{nome}, $params->{tipo_servico}, $params->{email},
    $params->{telefone}, $params->{site}, $params->{documento},
    $params->{observacoes}, $self->_encode_atributos($params->{atributos}),
    $id + 0, $cod_inep + 0,
  ) or return;
  return $self->_fornecedor_detail($row->{id}, $cod_inep);
}

sub delete_fornecedor ($self, $id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.inventario_fornecedores WHERE id = ? AND cod_inep = ? RETURNING id',
    $id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

sub _fornecedor_detail ($self, $id, $cod_inep) {
  my $r = $self->_row(
    'SELECT f.id, f.nome, f.tipo_servico, f.email, f.telefone, f.site,
            f.documento, f.observacoes, f.atributos, f.updated_at,
            (SELECT COUNT(*) FROM clean.inventario_itens i WHERE i.fornecedor_id = f.id) AS n_itens
     FROM   clean.inventario_fornecedores f
     WHERE  f.id = ? AND f.cod_inep = ?',
    $id + 0, $cod_inep + 0,
  ) or return;
  return $self->_fornecedor_out($r);
}

sub _fornecedor_out ($self, $r) {
  return {
    id           => $r->{id} + 0,
    nome         => $r->{nome},
    tipo_servico => $r->{tipo_servico},
    email        => $r->{email},
    telefone     => $r->{telefone},
    site         => $r->{site},
    documento    => $r->{documento},
    observacoes  => $r->{observacoes},
    atributos    => $self->_decode_atributos($r->{atributos}),
    n_itens      => $r->{n_itens} + 0,
    updated_at   => $r->{updated_at},
  };
}

# ---------------------------------------------------------------------------
# itens (recursos e serviços)
# ---------------------------------------------------------------------------

sub _item_select {
  return 'SELECT i.id, i.nome, i.descricao, i.quantidade, i.unidade, i.estado,
                 i.identificador, i.periodicidade, i.valor, i.data_aquisicao,
                 i.censo_ref, i.atributos, i.created_at, i.updated_at,
                 i.categoria_id, c.nome AS categoria_nome, c.tipo AS categoria_tipo,
                 i.fornecedor_id, f.nome AS fornecedor_nome,
                 (SELECT COUNT(*) FROM clean.inventario_anexos a WHERE a.item_id = i.id) AS n_anexos
          FROM   clean.inventario_itens i
          JOIN   clean.inventario_categorias c ON c.id = i.categoria_id
          LEFT JOIN clean.inventario_fornecedores f ON f.id = i.fornecedor_id';
}

sub list_itens ($self, $cod_inep, $filtros = {}) {
  my @where = ('i.cod_inep = ?');
  my @binds = ($cod_inep + 0);

  if (my $tipo = $filtros->{tipo}) {
    push @where, 'c.tipo = ?';
    push @binds, $tipo;
  }
  if (my $cat = $filtros->{categoria_id}) {
    push @where, 'i.categoria_id = ?';
    push @binds, $cat + 0;
  }
  if (my $q = $filtros->{q}) {
    $q =~ s/%/\\%/g;
    push @where, '(i.nome ILIKE ? ESCAPE \'\\\' OR i.descricao ILIKE ? ESCAPE \'\\\')';
    push @binds, '%' . $q . '%', '%' . $q . '%';
  }

  my $sql = $self->_item_select . ' WHERE ' . join(' AND ', @where)
    . ' ORDER BY c.tipo, lower(c.nome), lower(i.nome) LIMIT 500';

  return [ map { $self->_item_out($_) } @{ $self->_rows($sql, @binds) } ];
}

sub item_detail ($self, $id, $cod_inep) {
  my $r = $self->_row($self->_item_select . ' WHERE i.id = ? AND i.cod_inep = ?',
    $id + 0, $cod_inep + 0) or return;
  my $out = $self->_item_out($r);
  $out->{anexos} = $self->list_anexos_item($id + 0);
  return $out;
}

sub create_item ($self, $cod_inep, $gestor_id, $params = {}) {
  my $row = $self->_row(
    'INSERT INTO clean.inventario_itens
       (cod_inep, gestor_id, categoria_id, fornecedor_id, nome, descricao,
        quantidade, unidade, estado, identificador, periodicidade, valor,
        data_aquisicao, atributos)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb)
     RETURNING id',
    $cod_inep + 0, $self->_gestor_bind($gestor_id), $params->{categoria_id} + 0,
    $params->{fornecedor_id} ? $params->{fornecedor_id} + 0 : undef,
    $params->{nome}, $params->{descricao},
    $params->{quantidade} // 1, $params->{unidade}, $params->{estado},
    $params->{identificador}, $params->{periodicidade}, $params->{valor},
    $params->{data_aquisicao}, $self->_encode_atributos($params->{atributos}),
  ) or return;
  return $self->item_detail($row->{id}, $cod_inep);
}

sub update_item ($self, $id, $cod_inep, $params = {}) {
  my $row = $self->_row(
    'UPDATE clean.inventario_itens
     SET    categoria_id = ?, fornecedor_id = ?, nome = ?, descricao = ?,
            quantidade = ?, unidade = ?, estado = ?, identificador = ?,
            periodicidade = ?, valor = ?, data_aquisicao = ?,
            atributos = ?::jsonb, updated_at = NOW()
     WHERE  id = ? AND cod_inep = ?
     RETURNING id',
    $params->{categoria_id} + 0,
    $params->{fornecedor_id} ? $params->{fornecedor_id} + 0 : undef,
    $params->{nome}, $params->{descricao},
    $params->{quantidade} // 1, $params->{unidade}, $params->{estado},
    $params->{identificador}, $params->{periodicidade}, $params->{valor},
    $params->{data_aquisicao}, $self->_encode_atributos($params->{atributos}),
    $id + 0, $cod_inep + 0,
  ) or return;
  return $self->item_detail($id + 0, $cod_inep);
}

sub delete_item ($self, $id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.inventario_itens WHERE id = ? AND cod_inep = ? RETURNING id',
    $id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

sub item_state ($self, $id, $cod_inep) {
  return $self->_row(
    'SELECT id, cod_inep FROM clean.inventario_itens WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  );
}

sub _item_out ($self, $r) {
  return {
    id              => $r->{id} + 0,
    nome            => $r->{nome},
    descricao       => $r->{descricao},
    quantidade      => $r->{quantidade} + 0,
    unidade         => $r->{unidade},
    estado          => $r->{estado},
    identificador   => $r->{identificador},
    periodicidade   => $r->{periodicidade},
    valor           => defined $r->{valor} ? $r->{valor} + 0 : undef,
    data_aquisicao  => $r->{data_aquisicao},
    censo_ref       => $r->{censo_ref},
    atributos       => $self->_decode_atributos($r->{atributos}),
    categoria_id    => $r->{categoria_id} + 0,
    categoria_nome  => $r->{categoria_nome},
    categoria_tipo  => $r->{categoria_tipo},
    fornecedor_id   => $r->{fornecedor_id} ? $r->{fornecedor_id} + 0 : undef,
    fornecedor_nome => $r->{fornecedor_nome},
    n_anexos        => ($r->{n_anexos} // 0) + 0,
    updated_at      => $r->{updated_at},
  };
}

# ---------------------------------------------------------------------------
# importação do baseline do Censo (idempotente por censo_ref)
# ---------------------------------------------------------------------------

sub importar_censo ($self, $cod_inep, $gestor_id, $ano = undef) {
  $self->sincronizar_categorias_censo($cod_inep);
  my $censo = $self->inventario_censo($cod_inep, $ano);

  my %cat_id;
  for my $c (@{ $self->list_categorias($cod_inep) }) {
    $cat_id{ $c->{tipo} . "\0" . $c->{nome} } = $c->{id};
  }

  my $n = 0;
  if ($censo) {
    $self->_txn(sub {
      for my $g (@{ $censo->{grupos} }) {
        for my $it (@{ $g->{itens} }) {
          my $tipo = $TAXONOMIA_TIPO{ $it->{categoria} } or next;
          my $cid  = $cat_id{ $tipo . "\0" . $it->{categoria} } or next;
          my $row = $self->_row(
            'INSERT INTO clean.inventario_itens
               (cod_inep, gestor_id, categoria_id, nome, quantidade, unidade, censo_ref, atributos)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?::jsonb)
             ON CONFLICT (cod_inep, censo_ref) WHERE censo_ref IS NOT NULL DO NOTHING
             RETURNING id',
            $cod_inep + 0, $self->_gestor_bind($gestor_id), $cid + 0,
            $it->{label}, $it->{qtd} || 1, undef, $it->{key},
            $self->_encode_atributos({ origem => 'censo', grupo => $g->{label} }),
          );
          $n++ if $row;
        }
      }
    });
  }

  return { importados => $n, ano => $censo ? $censo->{ano} : $DEFAULT_YEAR + 0 };
}

# ---------------------------------------------------------------------------
# anexos
# ---------------------------------------------------------------------------

sub list_anexos_item ($self, $item_id) {
  my $rows = $self->_rows(
    'SELECT id, nome_original, mime, tamanho, created_at
     FROM   clean.inventario_anexos
     WHERE  item_id = ?
     ORDER  BY id',
    $item_id + 0,
  );
  return [ map {
    { id => $_->{id} + 0, nome_original => $_->{nome_original},
      mime => $_->{mime}, tamanho => $_->{tamanho} + 0, created_at => $_->{created_at} }
  } @$rows ];
}

sub registrar_anexo_item ($self, $item_id, $cod_inep, $info = {}) {
  return unless $self->item_state($item_id, $cod_inep);
  my $row = $self->_row(
    'INSERT INTO clean.inventario_anexos (item_id, nome_original, caminho, mime, tamanho)
     VALUES (?, ?, ?, ?, ?)
     RETURNING id',
    $item_id + 0, $info->{nome_original}, $info->{caminho}, $info->{mime}, $info->{tamanho} + 0,
  ) or return;
  return { id => $row->{id} + 0, anexos => $self->list_anexos_item($item_id) };
}

sub anexo_item_row ($self, $item_id, $cod_inep, $anexo_id) {
  return $self->_row(
    'SELECT a.id, a.nome_original, a.caminho, a.mime, a.tamanho
     FROM   clean.inventario_anexos a
     JOIN   clean.inventario_itens i ON i.id = a.item_id
     WHERE  a.id = ? AND a.item_id = ? AND i.cod_inep = ?',
    $anexo_id + 0, $item_id + 0, $cod_inep + 0,
  );
}

sub delete_anexo_item ($self, $item_id, $cod_inep, $anexo_id) {
  return $self->_row(
    'DELETE FROM clean.inventario_anexos a
     USING  clean.inventario_itens i
     WHERE  a.item_id = i.id AND a.id = ? AND a.item_id = ? AND i.cod_inep = ?
     RETURNING a.caminho',
    $anexo_id + 0, $item_id + 0, $cod_inep + 0,
  );
}

sub item_anexos_caminhos ($self, $item_id, $cod_inep) {
  return $self->_rows(
    'SELECT a.caminho
     FROM   clean.inventario_anexos a
     JOIN   clean.inventario_itens i ON i.id = a.item_id
     WHERE  a.item_id = ? AND i.cod_inep = ?',
    $item_id + 0, $cod_inep + 0,
  );
}

# ---------------------------------------------------------------------------
# helpers privados
# ---------------------------------------------------------------------------

sub _gestor_bind ($self, $gestor_id) {
  return defined $gestor_id && $gestor_id ? $gestor_id + 0 : undef;
}

sub _encode_atributos ($self, $atributos) {
  return '{}' unless ref $atributos eq 'HASH' && %$atributos;
  return Mojo::JSON::encode_json($atributos);
}

sub _decode_atributos ($self, $json) {
  return {} unless defined $json && length $json;
  my $decoded = eval { Mojo::JSON::decode_json($json) };
  return ref $decoded eq 'HASH' ? $decoded : {};
}

sub _txn ($self, $code) {
  my $ok = eval { $self->schema->storage->txn_do(sub { $code->() }); 1 };
  return 1 if $ok;
  die $@ || 'Erro de transação';
}

sub _rows ($self, $sql, @binds) {
  my $storage = $self->schema->storage;
  my $rows;
  $storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _row ($self, $sql, @binds) {
  return $self->_rows($sql, @binds)->[0];
}

1;
