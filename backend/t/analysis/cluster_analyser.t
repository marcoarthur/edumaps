use Test2::V0;
use Mojo::Base -signatures;
use strict;
use warnings;

# Força o mock local seguro da linha do ResultSet
package Mock::SchoolRow {
  use Mojo::Base -base;
  has ['id', 'numeric_features'];
}

# Força o mock do ResultSet do DBIx::Class
package Mock::ResultSet {
  use Mojo::Base -base;
  has 'rows' => sub { [] };
  has '_cursor' => 0;

  sub next ($self) {
    my $idx = $self->_cursor;
    if ($idx < scalar @{ $self->rows }) {
      $self->_cursor($idx + 1);
      return $self->rows->[$idx];
    }
    return undef;
  }

  sub reset ($self) {
    $self->_cursor(0);
    return $self;
  }
}

package main;

use EduMaps::Analysis::ClusterAnalyzer;

subtest 'Análise Estatística e Geração de Comentários Linguísticos' => sub {
  # 1. Massa de dados simulando escolas reais:
  # Características: [ Infraestrutura (0-10), Nota Saeb/IDEB (0-10) ]
  my $rows = [
    # Escolas com perfil Baixo
    Mock::SchoolRow->new(id => 101, numeric_features => [ 2.0, 3.5 ]),
    Mock::SchoolRow->new(id => 102, numeric_features => [ 2.5, 3.0 ]),

    # Escolas com perfil Médio
    Mock::SchoolRow->new(id => 201, numeric_features => [ 5.0, 5.5 ]),
    Mock::SchoolRow->new(id => 202, numeric_features => [ 5.5, 5.0 ]),

    # Escolas com perfil Alto (Destaques positivos)
    Mock::SchoolRow->new(id => 301, numeric_features => [ 9.0, 8.5 ]),
    Mock::SchoolRow->new(id => 302, numeric_features => [ 9.5, 9.0 ]),
  ];

  my $mock_rs = Mock::ResultSet->new(rows => $rows);

  # 2. Instancia o Analyzer configurando metadados textuais
  my $analyzer = EduMaps::Analysis::ClusterAnalyzer->new(
    resultset           => $mock_rs,
    feature_names       => [ 'Infraestrutura Escolar', 'Rendimento Saeb' ],
    id_getter           => 'id',
    clusterization_args => { n_clusters => 3, normalize => 1 }
  );

  ok( $analyzer->analyze(), 'Executou pipeline de análise sem estourar exceções' );

  # 3. Valida se mapeou todas as chaves de ID corretamente
  my $sample_clusters = $analyzer->sample_cluster;
  is( ref $sample_clusters, 'HASH', 'Retornou estrutura de mapeamento de clusters' );
  is( scalar(keys %$sample_clusters), 6, 'Mapeou exatamente as 6 escolas processadas' );

  # 4. Verifica a consistência dos agrupamentos por afinidade de dados
  is( $analyzer->cluster_for(101), $analyzer->cluster_for(102), 'Escolas vulneráveis caíram juntas' );
  is( $analyzer->cluster_for(301), $analyzer->cluster_for(302), 'Escolas de elite caíram juntas' );

  # 5. Validação da geração de comentários linguísticos dinâmicos
  my $comments = $analyzer->all_comments;
  is( ref $comments, 'HASH', 'Comentários gerados em estrutura de Hash' );

  # Encontra qual ID de cluster foi atribuído ao grupo alto
  my $high_cluster_id = $analyzer->cluster_for(301);
  my $comment_high    = $analyzer->cluster_comment($high_cluster_id);

  like( $comment_high, qr/Infraestrutura Escolar/, 'Comentário incluiu o nome da primeira feature' );
  like( $comment_high, qr/Rendimento Saeb/,        'Comentário incluiu o nome da segunda feature' );
  like( $comment_high, qr/(alto|muito alto)/,      'Classificou o cluster de elite corretamente' );
};

subtest 'Tratamento de Exceções e Parâmetros Obrigatórios' => sub {
  like(
    dies { EduMaps::Analysis::ClusterAnalyzer->new(id_getter => 'id')->feature_names },
    qr/Required features names/,
    'Lança exceção se names não for fornecido'
  );

  # # Criamos 4 observações (satisfaz n_clusters => 3), mas todas com apenas 1 dimensão
  # my $bad_rows = [
  #   Mock::SchoolRow->new(id => 991, numeric_features => [ 1.0 ]),
  #   Mock::SchoolRow->new(id => 992, numeric_features => [ 2.0 ]),
  #   Mock::SchoolRow->new(id => 993, numeric_features => [ 3.0 ]),
  #   Mock::SchoolRow->new(id => 994, numeric_features => [ 4.0 ]),
  # ];
  # my $bad_rs  = Mock::ResultSet->new(rows => $bad_rows);
  #
  # my $broken_analyzer = EduMaps::Analysis::ClusterAnalyzer->new(
  #   resultset     => $bad_rs,
  #   feature_names => [ 'Feature1', 'Feature2' ], # Espera 2, mas vai receber 1
  #   id_getter     => 'id',
  # );
  #
  # like(
  #   dies { $broken_analyzer->analyze },
  #   qr/numeric_features retornou 1 dimensões, feature_names espera 2/,
  #   'Valida e crasha se o número de dimensões físicas divergir do schema informado'
  # );
};

done_testing;
