# ============================================================================
# DEPRECATED (#137) — ver docs/analises/ivet.md (ivet-v1.0)
# ----------------------------------------------------------------------------
# `clean.censo_escolas_scores` (view de `scores_view`) tem 11 scores e NENHUM
# consumidor: nunca foi o índice do produto. NÃO usar em código novo.
# O índice canônico é `clean.mv_escolas_scores` (Result::MvEscolasScores).
# ============================================================================
package EduMaps::Schema::ResultSet::CensoEscolasScores;

use Mojo::Base "EduMaps::Schema::ResultSet::Base", -signatures;

1;
