package EduMaps::Analysis::Clusterization;
use Mojo::Base 'Mojo::EventEmitter', -signatures;
use PDL;
use PDL::Stats::Kmeans;   
use PDL::NiceSlice;
use DDP;

has n_clusters     => 5;
has max_iter       => 100;
has random_seed    => 123;
has normalize      => 1;
has verbose        => 0;

sub cluster ($self, $data, $n_clusters = $self->n_clusters, %opts) {
  $self->emit(start => { data_shape => ref($data) });

  my $pdl = $self->_to_pdl($data);
  $self->emit(loaded => { dims => [ $pdl->dims ] });

  if ($self->normalize) {
    $pdl = $self->_normalize($pdl);
    $self->emit(normalized => {});
  }

  my $k = $n_clusters // $self->n_clusters;
  my $seed = $opts{random_seed} // $self->random_seed;

  # Configuração do K-Means
  my %kmeans_opts = (
    NCLUS => $k,
    NTRY  => $opts{ntry} // 5,
    NSEED => $opts{nseed} // 1000,
    V     => $self->verbose ? 1 : 0,
    ( defined $seed ? (SEED => $seed) : () ),
  );

  my $pdl_transposto = $pdl->t;
  my %result = $pdl_transposto->kmeans(\%kmeans_opts);

  my $cluster_mask = $result{cluster};   
  my $cluster_ids = $cluster_mask->which_cluster;

  $self->emit(clustered => {
      clusters   => $cluster_ids,
      centers    => $result{centroid},
      iterations => $result{iters},
      r2         => $result{R2},
    });

  $self->emit(end => {});
  return { cluster => $cluster_ids, centers => $result{centroid}, iters => $result{iters}, r2 => $result{R2} };
}

sub _to_pdl ($self, $data) {
  if (ref($data) eq 'ARRAY') {
    my $rows = scalar @$data;
    my $cols = scalar @{$data->[0]};
    my $pdl = zeroes($cols, $rows);
    for my $i (0..$rows-1) {
      for my $j (0..$cols-1) {
        $pdl->set($j, $i, $data->[$i][$j]);
      }
    }
    return $pdl;
  }
  elsif (ref($data) eq 'PDL') {
    return $data;
  }
  elsif ( ref($data) && $data->can('next') ) {
    my @matrix;
    while (my $row = $data->next) {
      die "Row não implementa numeric_features" unless $row->can('numeric_features');
      push @matrix, $row->numeric_features;
    }
    return $self->_to_pdl(\@matrix);
  }
  else {
    die "Formato de dados não suportado";
  }
}

sub _normalize ($self, $pdl) {
  my $cols = $pdl->dim(0); # Quantidade de variáveis (ex: 2 ou 6)

  # Cria uma matriz vazia com o exato mesmo formato da original para receber o resultado
  my $norm = zeroes($pdl->dims);

  for my $j (0 .. $cols - 1) {
    # Isola a coluna/variável inteira usando uma fatia (slice)
    my $coluna = $pdl->slice("$j,:");

    my $min = $coluna->min;
    my $max = $coluna->max;
    my $range = $max - $min;

    # Evita divisão por zero para esta variável específica
    $range = 1 if $range == 0;

    # Executa a matemática elemento a elemento na fatia e salva na matriz de retorno
    my $coluna_norm = ($coluna - $min) / $range;
    $norm->slice("$j,:") .= $coluna_norm;
  }

  return $norm;
}

1;
