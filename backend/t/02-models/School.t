use lib qw(t/lib lib);
use Imports;
use EduMaps::Schema;
use Mojo::JSON qw(decode_json);

ok( eval { require EduMaps::Model::School }, 'just compile' );

subtest check_data_structures => sub {
  my $sch;
  my $school = eval {
    EduMaps::Model::School->new(schema => ($sch = EduMaps::Schema->go));
  };
  ok(!$@ , 'created school' ) or diag $@;

  # ensure we test each type of school
  for my $type ( qw/Privada Municipal Estadual/ ) {
    my $params = { dependencia_administrativa => $type };
    my $sample = $sch->resultset('Escolas')->search_rs($params)->as_hash->random_sample(1)->first->{codigo_inep};
    my $data   = eval { decode_json ($school->ideb_grades({id_escola => $sample})) };
    ok (!$@, "JSON decodified") or diag $@;

    # can be empty or have structure
    if (keys %$data) {
      is(
        $data,
        hash {
          field escola => hash {
            field id => L;
            field nome => L;
            field rede => L;
            field municipio => L;
            field codigo_ibge => L;
            end();
          };
          field indicador_rendimento => L;
          field notas_por_serie => L;
          field valores_observados_e_projecoes => L;
          end();
        },
        "data structure for $sample is ok"
      );
    }
  }
};

done_testing;
