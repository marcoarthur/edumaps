package EduMaps::Roles::DB::Scaling;
use Mojo::Base -role, -signatures;

requires qw(search_rs);

sub z_score($self, $col) {
  $self->add_derived(
    "z_score_for_$col" => qq< ($col -AVG($col) OVER()) / NULLIF(STDDEV($col) OVER(), 0) >
  );
}

sub minmax_scale($self, $col) {
  $self->add_derived(
    "minmax_for_$col" =>
      qq<
        ($col - MIN($col) OVER())
        / NULLIF(MAX($col) OVER() - MIN($col) OVER(), 0)
      >
  );
}

sub robust_scale($self, $col) {
  my $expr = 'percentile_cont(%f) WITHIN GROUP (ORDER BY %s.%s)';
  my $me   = $self->current_source_alias;
  my $rs   = $self->search_rs(undef); # cria um novo
  my $ps   = $rs->columns(
    [
      { p25 => \sprintf($expr, 0.25, $me, $col) },
      { p50 => \sprintf($expr, 0.50, $me, $col) },
      { p75 => \sprintf($expr, 0.75, $me, $col) },
    ]
  )->as_hash->single;

  $self->add_derived(
    "robust_for_$col" => qq|
    CASE
      WHEN $me.$col IS NULL THEN NULL
      ELSE
        ($me.$col - $ps->{p50}) / NULLIF($ps->{p75} - $ps->{p25}, 0)
      END
    |,
  );
}

sub rank_scale($self, $col) {
  $self->add_derived(
    "rank_for_$col" =>
      qq< RANK() OVER (ORDER BY $col) >
  );
}

sub log_scale($self, $col, $offset = 0) {
  $self->add_derived(
    "log_for_$col" =>
      qq< LN($col + $offset) >
  );
}

sub unit_vector_scale($self, $col) {
  $self->add_derived(
    "unit_for_$col" =>
      qq<
        $col
        / NULLIF(
            SQRT(SUM($col * $col) OVER()),
            0
          )
      >
  );
}

sub boxcox($self, $col, $lambda = 0) {
  my $expr = $lambda == 0
    ? qq< LN($col) >
    : qq< (POWER($col, $lambda) - 1) / $lambda >;

  $self->add_derived(
    "boxcox_for_$col" => $expr
  );
}

sub quantile_scale($self, $col) {
  $self->add_derived(
    "quantile_for_$col" =>
      qq< CUME_DIST() OVER (ORDER BY $col) >
  );
}

1;
