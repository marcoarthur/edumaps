#!/usr/bin/env perl
use Mojo::Base -strict, -signatures;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Ajuste estes dois use/connect para o bootstrap real da app —
# aqui assumo que EduMaps::Schema é o schema DBIC já usado pelo Model.
use EduMaps::Schema;
use EduMaps::Model::Rank::School;

# ============================================================================
# bin/refresh_ranking_escola.pl
#
# Popula/atualiza analytics.ranking_escola a partir de clean.mv_escolas_scores
# e clean.ideb_notas_escolas, reaproveitando indicator_registry e network_map
# de EduMaps::Model::Rank::School como fonte única da verdade — evita manter
# os 16 indicadores duplicados em SQL hardcoded.
#
# Disparo:
#   1) logo após "REFRESH MATERIALIZED VIEW clean.mv_escolas_scores"
#   2) logo após cada carga do IDEB em clean.ideb_notas_escolas
#   3) 1x/dia via cron/systemd timer, como rede de segurança
#
# Uso:
#   perl bin/refresh_ranking_escola.pl
#   perl bin/refresh_ranking_escola.pl --source mv     # só indicadores 'mv'
#   perl bin/refresh_ranking_escola.pl --source ideb   # só indicadores 'ideb'
# ============================================================================

my %opt = (source => 'all');
for (my $i = 0; $i < @ARGV; $i++) {
  if ($ARGV[$i] eq '--source') { $opt{source} = $ARGV[++$i] }
}

my $schema = EduMaps::Schema->go;
my $rank_model = EduMaps::Model::Rank::School->new(schema => $schema);
my $dbh        = $schema->storage->dbh;

my $registry    = $rank_model->indicator_registry;
my $network_map = $rank_model->network_map;

my $ok = eval {
  $dbh->begin_work;

  for my $indicator_id (sort keys %$registry) {
    my $def = $registry->{$indicator_id};
    next if $opt{source} ne 'all' && $opt{source} ne $def->{source};

    if ($def->{source} eq 'mv') {
      _refresh_mv_indicator($dbh, $network_map, $indicator_id, $def);
    }
    else {
      _refresh_ideb_indicator($dbh, $network_map, $indicator_id, $def);
    }
  }

  $dbh->commit;
  1;
};

unless ($ok) {
  my $err = $@ // 'erro desconhecido';
  $dbh->rollback;
  die "refresh_ranking_escola.pl falhou, rollback aplicado: $err\n";
}

print "refresh_ranking_escola.pl concluído com sucesso.\n";

# ============================================================================
# Privado: indicadores da fonte "mv" (clean.mv_escolas_scores)
# ============================================================================
sub _refresh_mv_indicator ($dbh, $network_map, $indicator_id, $def) {
  my $column = $def->{column};
  my @redes  = ('todas', sort keys %{ $network_map->{mv} });

  for my $rede (@redes) {
    my $network_filter_sql = '';
    my @network_bind;
    if ($rede ne 'todas') {
      $network_filter_sql = 'AND esc.tp_dependencia = ?';
      @network_bind = ($network_map->{mv}{$rede});
    }

    my ($year) = $dbh->selectrow_array(
      qq{SELECT MAX(nu_ano_censo) FROM clean.mv_escolas_scores WHERE $column IS NOT NULL}
    );
    next unless $year;

    my $sql = qq{
      INSERT INTO analytics.ranking_escola
      (indicador_id, rede, id_escola, ano, valor,
        rank_municipio, total_municipio,
        rank_estado, total_estado,
        rank_nacional, total_nacional,
        data_atualizacao)
      SELECT
      ?, ?, co_entidade, ?, value,
      rank_municipio, total_municipio,
      rank_estado, total_estado,
      rank_nacional, total_nacional,
      now()
      FROM (
        SELECT
        me.co_entidade,
        me.$column AS value,
        RANK()  OVER (PARTITION BY esc.co_municipio ORDER BY me.$column DESC) AS rank_municipio,
        COUNT(*) OVER (PARTITION BY esc.co_municipio)                          AS total_municipio,
        RANK()  OVER (PARTITION BY esc.co_uf ORDER BY me.$column DESC)         AS rank_estado,
        COUNT(*) OVER (PARTITION BY esc.co_uf)                                 AS total_estado,
        RANK()  OVER (ORDER BY me.$column DESC)                                AS rank_nacional,
        COUNT(*) OVER ()                                                       AS total_nacional
        FROM clean.mv_escolas_scores me
        JOIN clean.censo_escolas esc
        ON esc.co_entidade = me.co_entidade
        AND esc.nu_ano_censo = me.nu_ano_censo
        WHERE me.nu_ano_censo = ?
        AND me.$column IS NOT NULL
        AND esc.tp_situacao_funcionamento = 1
        $network_filter_sql
      ) ranked
      ON CONFLICT (indicador_id, rede, id_escola) DO UPDATE SET
      ano              = EXCLUDED.ano,
      valor            = EXCLUDED.valor,
      rank_municipio   = EXCLUDED.rank_municipio,
      total_municipio  = EXCLUDED.total_municipio,
      rank_estado      = EXCLUDED.rank_estado,
      total_estado     = EXCLUDED.total_estado,
      rank_nacional    = EXCLUDED.rank_nacional,
      total_nacional   = EXCLUDED.total_nacional,
      data_atualizacao = EXCLUDED.data_atualizacao
    };

    $dbh->do($sql, undef, $indicator_id, $rede, $year, $year, @network_bind);
    print "  [$indicator_id] rede=$rede ano=$year OK\n";
  }
}

# ============================================================================
# Privado: indicadores da fonte "ideb" (clean.ideb_notas_escolas)
# ============================================================================
sub _refresh_ideb_indicator ($dbh, $network_map, $indicator_id, $def) {
  my $column = $def->{column};
  my $etapa  = $def->{etapa}
    or die "Indicador ideb sem etapa definida: $indicator_id\n";
  my @redes  = ('todas', sort keys %{ $network_map->{ideb} });

  for my $rede (@redes) {
    my $network_filter_sql = '';
    my @network_bind;
    if ($rede ne 'todas') {
      $network_filter_sql = 'AND rede = ?';
      @network_bind = ($network_map->{ideb}{$rede});
    }

    my ($year) = $dbh->selectrow_array(
      qq{SELECT MAX(ano) FROM clean.ideb_notas_escolas WHERE etapa = ? AND $column IS NOT NULL}
      . ($rede ne 'todas' ? ' AND rede = ?' : ''),
      undef, $etapa, @network_bind
    );
    next unless $year;

    my $sql = qq{
      INSERT INTO analytics.ranking_escola
      (indicador_id, rede, id_escola, ano, valor,
        rank_municipio, total_municipio,
        rank_estado, total_estado,
        rank_nacional, total_nacional,
        data_atualizacao)
      SELECT
      ?, ?, id_escola, ?, value,
      rank_municipio, total_municipio,
      rank_estado, total_estado,
      rank_nacional, total_nacional,
      now()
      FROM (
        SELECT
        id_escola,
        $column AS value,
        RANK()  OVER (PARTITION BY co_municipio ORDER BY $column DESC) AS rank_municipio,
        COUNT(*) OVER (PARTITION BY co_municipio)                       AS total_municipio,
        RANK()  OVER (PARTITION BY sg_uf ORDER BY $column DESC)         AS rank_estado,
        COUNT(*) OVER (PARTITION BY sg_uf)                              AS total_estado,
        RANK()  OVER (ORDER BY $column DESC)                            AS rank_nacional,
        COUNT(*) OVER ()                                                AS total_nacional
        FROM clean.ideb_notas_escolas
        WHERE ano = ?
        AND etapa = ?
        AND $column IS NOT NULL
        $network_filter_sql
      ) ranked
      ON CONFLICT (indicador_id, rede, id_escola) DO UPDATE SET
      ano              = EXCLUDED.ano,
      valor            = EXCLUDED.valor,
      rank_municipio   = EXCLUDED.rank_municipio,
      total_municipio  = EXCLUDED.total_municipio,
      rank_estado      = EXCLUDED.rank_estado,
      total_estado     = EXCLUDED.total_estado,
      rank_nacional    = EXCLUDED.rank_nacional,
      total_nacional   = EXCLUDED.total_nacional,
      data_atualizacao = EXCLUDED.data_atualizacao
    };

    $dbh->do($sql, undef, $indicator_id, $rede, $year, $year, $etapa, @network_bind);
    print "  [$indicator_id] rede=$rede ano=$year OK\n";
  }
}
