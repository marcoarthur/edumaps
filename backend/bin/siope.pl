#!/usr/bin/env perl

use Mojo::Base -strict, -signatures;
use Getopt::Long;
use lib qw(./lib);
use Pod::Usage;
use DateTime;
use Syntax::Keyword::Try;
use EduMaps::Siope::Scrap::SpreadSheet::Gastos;
use utf8;
use DDP;
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my %options = (
  debug       => 0,
  help        => 0,
  cod_mun     => undef,
  ano         => DateTime->now->year,
  captcha     => $ENV{CAPTCHA},
);

GetOptions(
  'debug'           => \$options{debug},
  'help|h'          => \$options{help},
  'cod_mun=s'       => \$options{cod_mun},
  'ano=s'           => \$options{ano},
  'captcha=s'       => \$options{captcha},
) or pod2usage(2);

pod2usage(1) if     $options{help};
pod2usage(1) unless $options{cod_mun}; # required
pod2usage(1) unless $options{captcha}; # required

if ($options{debug}) {
  $ENV{DBIC_TRACE_PROFILE} = 'console';
  $ENV{DBIC_TRACE} = 1;
  $ENV{MOJO_CLIENT_DEBUG} = 1;
}

sub debug_msg {
  say join ("\n", @_);
}

# populate table clean.remuneracao
sub populate {

  my $api = EduMaps::Siope::Scrap::SpreadSheet::Gastos->new(
    cod_mun => $options{cod_mun},
    captcha => $options{captcha},
    ano     => $options{ano},
  );

  # load later
  require EduMaps::Schema;
  my $sch = EduMaps::Schema->go;
  my $rs  = $sch->resultset('RemuneracaoMunicipal');
  my $mun = $sch->resultset('MunicipiosSp')->find({ codigo_ibge_antigo => $options{cod_mun} });
  unless ($mun) {
    die sprintf("Código inválido de município %s", $options{cod_mun});
  }
  debug_msg(
    sprintf("Buscando dados FNDE para município de %s", uc $mun->nome_municipio)
  ) if $options{debug};

  my $col_order = [ 
    qw(ano mes nome_profissional cpf cod_inep escola carga_horaria tipo categoria 
      situacao segmento_ensino salario_base salario_fundeb_max salario_fundeb_min
      salario_outros salario_total cod_municipio rede)
  ];

  try {
    # adiciona o cod_municipio e rede
    my @rows = map { 
      my $row = $_;
      push @$row, $options{cod_mun}, 'Municipal';
      $row;
    } $api->get_and_process->@*;

    # carrega no banco de dados --bulk insertion--
    my $population = [$col_order, @rows];
    $rs->populate($population);
    $api->cleanup;
  } catch ($err){
    warn "Error: $err";
  }
}

sub main {
  debug_msg(sprintf ('Salvando dados do município de código: %d. Ano: %d. Processo: %d',$options{cod_mun},$options{ano}, $$)) if $options{debug};
  populate;
  debug_msg(sprintf ('Finalizado (%d)', $$)) if $options{debug};
}

main;

__END__

=pod

=encoding UTF-8

=head1 NAME

siope.pl - Carrega dados do Sistema SIOPE sobre informações de remuneração

=head1 SYNOPSIS

  # Uso básico
  ./bin/siope.pl --cod_mun='350190'

  # Debug
  ./bin/siope.pl --debug

=head1 OPTIONS

=over 4

=item B<--cod_mun>=I<código do município>

Obrigatório: Código do município a ser buscado.

=item B<--ano>=I<ano da busca>

Opicional: Ano para a remuneração, esta opção por default é o ano corrente.

=item B<--captcha>=I<segredo>

Obrigatório: O segredo do captcha. Deve-se pegar da URL no browser usando a consulta manual ao site
L<https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do>, do parâmetro
g-recaptcha-response na URL.

=item B<--debug>

Opicional: Ativar modo debug

=item B<--help>

Mostrar esta ajuda

=back

=cut
