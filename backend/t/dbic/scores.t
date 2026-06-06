use lib qw(./t/lib);
use Imports;
use Utils qw(filter_resultsets c);

subtest score_escola_tests => sub {
  my $score = filter_resultsets(
    sub ($rs) { 
      return $rs->isa('EduMaps::Schema::ResultSet::MvEscolasScores');
    }
  )->[0];

  fail "cannot found Scores ResultSet" unless defined $score;
  my $sample = $score->random_sample->get_all;
  my @scores = qw/
  score_capacidade_atendimento
  score_infraestrutura
  score_capacitacao_docente
  score_diversidade_discente
  score_capacidade_gestora
  score_sustentabilidade
  /
  ;

  my @relations = qw/escola/;

  is($sample->size, 10, "right sample size");

  $sample->each(
    sub ($x, $idx) {
      can_ok($x, @scores, @relations);
      my $meth;

      c(map { $meth = $_; $x->$meth } @scores)->each( 
        sub {
          unless (defined) {
            ok(1, 'null value for score can happen');
          }
          ok (($_ >= 0) && ($_ <= 10), 'under right scale') or diag "$meth: $_";
        }
      );
      c(map { $meth = $_; $x->$meth } @relations)->each( 
        sub {
          ok (defined $_, "found relation for ->$meth()");
          isa_ok($_, 'DBIx::Class::Core');
        }
      );
    }
  );
};

done_testing;
