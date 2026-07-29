package EduMaps::Schema::ResultSet::RankingEscola;
use Mojo::Base 'EduMaps::Schema::ResultSet::Base', -signatures;
use Carp qw(croak);

sub top_schools ($self, %args){
  my $indicador = $args{indicador_id} or croak "indicador_id é obrigatório";
  my $ano       = $args{ano}          or croak "ano é obrigatório";
  my $rede      = $args{rede} // 'todas';
  my $geo       = $args{geography} // 'nacional';
  my $limit     = $args{limit} // 10;

  $geo =~ /^(municipio|estado|nacional)$/
    or croak "geography deve ser 'municipio', 'estado' ou 'nacional'";

  my $rank_col = "rank_$geo";
  my $rs = $self->search(
    {
      indicador_id => $indicador,
      rede         => $rede,
      ano          => $ano,
      # rank não pode ser nulo (garante que há valor)
      -and => [
        "$rank_col" => { '!=', undef },
      ],
    },
    {
      join      => 'escola',
      '+columns' => [ 'escola.no_entidade', 'escola.co_municipio', 'escola.co_uf' ],
      order_by  => { -asc => $rank_col },
    }
  );
  $rs = $rs->limit($limit) if defined $limit;
  return $rs;
}

sub bottom_schools ($self, %args) {
  my $indicador = $args{indicador_id} or croak "indicador_id é obrigatório";
  my $ano       = $args{ano}           or croak "ano é obrigatório";
  my $rede      = $args{rede} // 'todas';
  my $geo       = $args{geography} // 'nacional';
  my $limit     = $args{limit} // 10;

  $geo =~ /^(municipio|estado|nacional)$/
    or croak "geography deve ser 'municipio', 'estado' ou 'nacional'";

  my $rank_col = "rank_$geo";
  my $rs = $self->search(
    {
      indicador_id => $indicador,
      rede         => $rede,
      ano          => $ano,
      "$rank_col"  => { '!=', undef },
    },
    {
      join      => 'escola',
      '+columns' => [ 'escola.no_entidade', 'escola.co_municipio', 'escola.co_uf' ],
      order_by  => { -desc => $rank_col },   # maiores ranks primeiro
    }
  );
  $rs = $rs->limit($limit) if defined $limit;
  return $rs;
}

sub best_in_each_municipio ( $self, %args ) {
  my $indicador = $args{indicador_id} or croak "indicador_id é obrigatório";
  my $ano       = $args{ano}          or croak "ano é obrigatório";
  my $rede      = $args{rede} // 'todas';

  # Retorna apenas as linhas onde rank_municipio = 1
  return $self->search_rs(
    {
      indicador_id    => $indicador,
      rede            => $rede,
      ano             => $ano,
      rank_municipio  => 1,
    },
    {
      join      => 'escola',
      '+columns' => [ 'escola.no_entidade', 'escola.co_municipio', 'escola.co_uf' ],
      order_by  => { -asc => 'escola.no_entidade' },
    }
  );
}


sub ranking_summary ($self, %args) {
  my $indicador = $args{indicador_id} or croak "indicador_id é obrigatório";
  my $ano       = $args{ano}           or croak "ano é obrigatório";
  my $rede      = $args{rede} // 'todas';
  my $geo       = $args{geography} // 'nacional';
  my $bins      = $args{bins} // [ 1, 5, 10, 50, 100 ];

  $geo =~ /^(municipio|estado|nacional)$/
    or croak "geography deve ser 'municipio', 'estado' ou 'nacional'";

  my $rank_col = "rank_$geo";
  my $rs = $self->search(
    {
      indicador_id => $indicador,
      rede         => $rede,
      ano          => $ano,
      "$rank_col"  => { '!=', undef },
    }
  );

  # Total de escolas com ranking
  my $total = $rs->count;

  # Estatísticas básicas: min, max, avg (usando SQL)
  my $stats = $self->search_rs(
    {
      indicador_id => $indicador,
      rede         => $rede,
      ano          => $ano,
      "$rank_col"  => { '!=', undef },
    },
    {
      select => [
        { min => $rank_col },
        { max => $rank_col },
        { avg => $rank_col },
      ],
      as => [ 'min_rank', 'max_rank', 'avg_rank' ],
    }
  )->first;

  # Contagem por faixas (bins) -> usamos subconsultas separadas para cada faixa
  my %bin_counts;
  for my $bin (@$bins) {
    my $count = $self->search_rs(
      {
        indicador_id => $indicador,
        rede         => $rede,
        ano          => $ano,
        "$rank_col"  => { '<=', $bin },
      }
    )->count;
    $bin_counts{"<= $bin"} = $count;
  }

  # Escolas sem ranking
  my $without_rs = $self->schools_without_ranking(
    indicador_id => $indicador,
    ano          => $ano,
    rede         => $rede,
  );
  my $without_count = $without_rs->count;

  return {
    total        => $total,
    min_rank     => $stats->get_column('min_rank'),
    max_rank     => $stats->get_column('max_rank'),
    avg_rank     => sprintf('%.2f', $stats->get_column('avg_rank')),
    bin_counts   => \%bin_counts,
    schools_without => $without_count,
  };
}

sub schools_without_ranking ($self, %args) {
  my $indicador = $args{indicador_id} or croak "indicador_id é obrigatório";
  my $ano       = $args{ano}           or croak "ano é obrigatório";
  my $rede      = $args{rede} // 'todas';

  # Obtém o schema a partir do resultset
  my $schema = $self->result_source->schema;

  # Alias da tabela ranking para a subconsulta
  my $ranking_rs = $schema->resultset('RankingEscola')->search_rs(
    {
      indicador_id => $indicador,
      rede         => $rede,
      ano          => $ano,
    },
    { columns => ['id_escola'] }
  );

  # Resultsets de escolas que não estão na subconsulta
  return $schema->resultset('CensoEscolas')->search_rs(
    {
      co_entidade => { -not_in => $ranking_rs->as_query },
    },
    {
      order_by => 'no_entidade',
    }
  );
}

1;
