# t/02-models/docentes_formacao_continuada.t
# #522 (QU-01): as colunas qt_doc_bas_espec_* do Censo são a formação
# continuada de no mínimo 80 horas, não a especialização (pós-graduação). Os
# comentários do banco, que chegam ao agrupamento e ao Assistente do Censo,
# dizem isso (change docentes_formacao_continuada_rotulos).
use lib qw(t/lib lib);
use Imports;
use EduMaps::Schema;
use utf8;

my $dbh = EduMaps::Schema->go->storage->dbh;

my $coment = sub ($tab, $col) {
  scalar $dbh->selectrow_array(q{
    SELECT col_description(a.attrelid, a.attnum) FROM pg_attribute a
     WHERE a.attrelid = to_regclass(?) AND a.attname = ? AND NOT a.attisdropped
  }, undef, $tab, $col);
};

my $espec = $dbh->selectcol_arrayref(q{
  SELECT a.attname FROM pg_attribute a
   WHERE a.attrelid = 'clean.censo_docentes'::regclass
     AND a.attname LIKE 'qt\_doc\_bas\_espec\_%' AND NOT a.attisdropped
   ORDER BY a.attnum
});
is scalar @$espec, 19, 'as 19 colunas de formação continuada';
for my $c (@$espec) {
  my $d = $coment->('clean.censo_docentes', $c) // '';
  unlike $d, qr/especializa/i, "$c: não diz especialização";
  like $d, qr/formação continuada/, "$c: diz formação continuada";
}
like $coment->('clean.censo_docentes', 'qt_doc_bas_espec_nenhum'),
  qr/^Docentes sem formação continuada de no mínimo 80 horas/, 'espec_nenhum: sem formação continuada';
# #524 (QT-02): comentário curto; o agrupamento faz o rótulo da tela com ele
like $coment->('clean.school_indicators', 'prop_sem_especializacao'),
  qr/^Docentes sem formação continuada \(/, 'school_indicators: comentário curto (#524)';
like $coment->('clean.school_indicators', 'prop_efetivos'),
  qr/^Proporção de docentes concursados \(.*vazia nas privadas/, 'concursados: vazia nas privadas (#524)';
like $coment->('clean.mv_escolas_scores', 'score_capacitacao_docente'),
  qr/NULL sem docente \(#467\)/, 'capacitação docente: sem docente, NULL (#467, de volta na #524)';
like $coment->('clean.mv_escolas_scores', 'score_capacitacao_docente'),
  qr/formação continuada/, 'capacitação docente: formação continuada';

done_testing;
