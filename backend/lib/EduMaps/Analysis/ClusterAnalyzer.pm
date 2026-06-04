package EduMaps::Analysis::ClusterAnalyzer;
use Mojo::Base -base, -signatures;
use EduMaps::Analysis::Clusterization;
use List::Util qw(sum);

has 'resultset';
has 'clusterization_args' => sub { +{} };
has 'id_getter'          => sub { die "requires the id" };
has 'feature_names'      => sub { die "Required features names" };

# Atributos internos
has '_cluster_result';
has '_sample_cluster';
has '_scores';
has '_comments';

sub analyze ($self) {
  # Limpa o estado interno para permitir re-análise segura se necessário
  $self->_cluster_result(undef);
  $self->_sample_cluster(undef);
  $self->_scores(undef);
  $self->_comments(undef);

  my $clusterer = EduMaps::Analysis::Clusterization->new(
    %{ $self->clusterization_args }
  );

  my $raw = $clusterer->cluster($self->resultset);
  $self->_cluster_result($raw);

  my $cluster_ids = $raw->{cluster}; # Objeto PDL
  my @ids_pdl     = $cluster_ids->list;

  my $rs = $self->resultset;
  $rs->reset;

  my %sample_cluster;
  my %scores;
  my $idx = 0;

  while (my $row = $rs->next) {
    my $id_value = $self->_extract_id($row);
    my $id_key   = $self->_id_to_key($id_value);
    $sample_cluster{$id_key} = $ids_pdl[$idx];

    my $features = $self->_extract_features($row);
    $scores{$id_key} = $features;
    $idx++;
  }

  $self->_sample_cluster(\%sample_cluster);
  $self->_scores(\%scores);
  $self->_comments( $self->_interpret() );

  return $self;
}

sub _extract_id ($self, $row) {
  my $getter = $self->id_getter;
  if (ref $getter eq 'CODE') {
    return $getter->($row);
  } elsif ($row->can($getter)) {
    return $row->$getter();
  } else {
    die "Não foi possível extrair ID da linha: método '$getter' não encontrado";
  }
}

sub _id_to_key ($self, $id) {
  return ref $id eq 'ARRAY' ? join('|', @$id) : "$id";
}

sub _extract_features ($self, $row) {
  my $n_feat = scalar @{ $self->feature_names };
  if ($row->can('numeric_features')) {
    my $feats = $row->numeric_features;
    die "numeric_features retornou " . scalar(@$feats) . " dimensões, feature_names espera $n_feat"
    unless @$feats == $n_feat;
    return $feats;
  } else {
    die "Cannot extract features no ->numeric_features() method";
  }
}

sub _interpret ($self) {
  my $sample_cluster = $self->_sample_cluster;
  my $scores         = $self->_scores;
  my $feature_names  = $self->feature_names;
  my $n_features     = scalar @$feature_names;

  my %cluster_scores;
  for my $id (keys %$sample_cluster) {
    my $cl = $sample_cluster->{$id};
    push @{ $cluster_scores{$cl} }, $scores->{$id};
  }

  my @all_scores = values %$scores;
  my @means;
  my @stds;

  for my $i (0 .. $n_features-1) {
    my @vals = map { $_->[$i] } @all_scores;
    my $mean = sum(@vals) / @vals;
    my $var  = sum(map { ($_ - $mean)**2 } @vals) / @vals;
    my $std  = sqrt($var);
    push @means, $mean;
    push @stds,  $std == 0 ? 1 : $std;
  }

  my %comments;
  for my $cl (sort { $a <=> $b } keys %cluster_scores) {
    my $points = $cluster_scores{$cl};
    my @cluster_means;
    for my $i (0 .. $n_features-1) {
      my $sum = sum(map { $_->[$i] } @$points);
      push @cluster_means, $sum / @$points;
    }

    my @destaques;
    for my $i (0 .. $n_features-1) {
      my $z = ($cluster_means[$i] - $means[$i]) / $stds[$i];
      my $class = $self->_classify($z);
      next if $class eq 'médio';
      push @destaques, sprintf "%s %s (%.1f)", $class, $feature_names->[$i], $cluster_means[$i];
    }

    my $comentario = @destaques
    ? "Cluster $cl destaca‑se por: " . join("; ", @destaques) . "."
    : "Cluster $cl apresenta perfil médio em todos os indicadores.";
    $comments{$cl} = $comentario;
  }
  return \%comments;
}

sub _classify ($self, $z) {
  return 'muito alto' if $z > 1.5;
  return 'alto'       if $z > 0.5;
  return 'médio'      if $z >= -0.5;
  return 'baixo'      if $z > -1.5;
  return 'muito baixo';
}

sub sample_cluster ($self) { return $self->_sample_cluster }
sub cluster_for ($self, $id) { return $self->_sample_cluster->{ $self->_id_to_key($id) } }
sub all_comments ($self) { return $self->_comments }
sub cluster_comment ($self, $cluster_id) { return $self->_comments->{$cluster_id} }
sub raw_result ($self) { return $self->_cluster_result }

1;
