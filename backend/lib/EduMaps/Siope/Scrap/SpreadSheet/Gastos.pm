package EduMaps::Siope::Scrap::SpreadSheet::Gastos;
use Mojo::Base -base, -signatures, -async_await;
use Mojo::UserAgent;
use Mojo::Util qw(trim);
use Mojo::Exception;
use Spreadsheet::Read;
use Syntax::Keyword::Try;
use IO::All;
use utf8;

=pod

=encoding UTF-8

=head1 NAME 

EduMaps::Siope::Scrap::SpreadSheet::Gastos - Scrapper para captura dos dados do SIOPE FNDE


=head1 SYNOPSIS

  
  my $api = EduMaps::Siope::Scrap::SpreadSheet::Gastos->new(
    cod_mun => 355091,
    captcha => $ENV{CAPTCHA_SIOPE},
    ano     => 2023
  );

  my $rows = $api->get_and_process;

=head1 DESCRIPTION

O módulo é cliente (ou melhor scrapper) para baixar dados público do site do FNDE de modo a obter
os dados de remuneração dos profissionais vinculados à educação na rede municipal de cada município brasileiro.

É necessário prover o ano, código do município (código antigo do IBGE com 6 dígitos) e o captcha
gerado manualmente para validação humana (gere visitando o site e fazendo uma consulta).

=cut

# endpoint
has base => sub {
  Mojo::URL->new('https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do');
};

has ua => sub { 
  my $ua = Mojo::UserAgent->new;
  $ua->transactor->name(
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36'
  );
  $ua->connect_timeout(90);
  return $ua;
};

# required fields
has cod_mun => sub { die "Necessito de um codigo de municipio, Ex. 350110" };
has ano     => sub { die "Necessito um ano, Ex. 2023" };
has captcha => sub { die "Necessito o captcha como parametro" };

# processed rows
has _rows   => sub { [] };

# temporarely downloaded xlsx file
has sheet   => sub ($self) { 
  sprintf "/tmp/%s_%s.xlsx", $self->cod_mun, $self->ano;
};

# query parameters
sub _data($self) {
  return {
    acao        => 'excel',
    cod_uf      => substr($self->cod_mun, 0, 2),
    municipios  => $self->cod_mun,
    anos        => $self->ano,
    mes         => 0,
    'g-recaptcha-response' => $self->captcha
  };
}


=head1 METHODS

=head2 get_data_p

     my $file = await $self->get_data_p;

Faz uma requisição HTTP assíncrona para baixar um arquivo Excel com dados de remuneração municipal
do sistema SIOPE/FNDE e salva localmente.

=head3 Descrição

Este método realiza os seguintes passos:

=over 4

=item 1. Configura os parâmetros de consulta na URL base usando os dados fornecidos

=item 2. Executa uma requisição HTTP GET assíncrona para o endpoint do FNDE

=item 3. Valida se a resposta foi bem-sucedida (status HTTP 2xx)

=item 4. Verifica se o content-type indica um arquivo Excel

=item 5. Salva o conteúdo binário em um arquivo local no diretório /tmp/

=item 6. Parseia o conteúdo e retornar um `Array of Arrays` representando os dados da tabela

=back

=head3 Retorno

Retorna um L<Mojo::Promise> que quando resolvido contém:

=over 4

=item C<Str> - Caminho completo do arquivo Excel salvo

=back

=head3 Exceções

=over 4

=item Lança C<Mojo::Exception> com mensagem de erro se:

=over 8

=item * A requisição HTTP falhar

=item * O content-type não indicar um arquivo Excel

=item * Os parâmetros obrigatórios não estiverem definidos

=item * se houver erro ao salvar o arquivo

=back

=back

=head3 Estrutura do Arquivo Salvo

O arquivo é salvo com o nome no formato:

    /tmp/{codigo_municipio}_{ano}.xlsx

Exemplo: C</tmp/350030_2024.xlsx>
=cut

async sub get_data_p($self) {
  $self->base->query( %{$self->_data} );
  my $tx = await $self->ua->get_p( $self->base );

  unless ($tx->result->is_success) {
    my $error = $tx->error;
    my $err_msg = sprintf "❌ Erro de conexão: %s\n", $error->{message} || 'Unknown error';
    Mojo::Exception->throw($err_msg);
  }

  unless ( $tx->result->headers->content_type =~ /excel/i ) {
    Mojo::Exception->throw("Erro API não retornou um arquivo excel");
  }

  my $data = $tx->result->body;

  try {
    io($self->sheet)->binary->print($data);
  } catch($e) {
    Mojo::Exception->throw("Não foi possível salvar o arquivo: $e");
  }

  return $self->sheet;
}

=head2 get_data

     my $file = $self->get_data;

Versão blocked (síncrona) de C<get_data_p>.

=cut

sub get_data($self) {
  my $fname;
  $self->get_data_p
  ->then( sub ($file) { $fname = $file; })
  ->catch( 
    sub ($err) {
      Mojo::Exception->throw("Falha ao obter dados: $err");
    }
  )->wait;

  return $fname;
}

sub _process_sheet($self) {
  # get data from server if not found the sheet file
  $self->get_data unless -f $self->sheet;
  my $sheet   = Spreadsheet::Read->new($self->sheet)->sheet(1);
  my @rows    = $sheet->rows;

  # discard the headers
  my $header  = shift @rows;
  # discard last value that is the summation
  pop @rows;

  # make it numeric converting from
  # "     2.455,52" to 2455.52
  @rows = map {
    my $row = $_;

    # trim all columns
    $_ = trim $_ for @$row;

    # convert to numeric the columns for salary
    $_ = $self->_to_num($_) for @$row[11..15];
    $row;
  } @rows;

  # save processed rows
  $self->_rows(\@rows);
  $self;
}

=head2 get_and_process

  my $rows = $self->get_and_process;

=head3 Descrição

O método não recebe parâmetros e retorna todas as linhas da planilha capturada.
(sem cabeçalhos e nem linhas totais - (linha inicial e final, respectivamente).

=cut

sub get_and_process($self) { return $self->_process_sheet->_rows; }

sub _to_num($self, $val) {
  $val =~ s/\.//g;
  $val =~ s/,/./g;
  return $val;
}

=head2 cleanup

  $self->cleanup;

Remove o arquivo Excel temporário do disco.

=cut

sub cleanup($self) {
  if (-f $self->sheet) {
    unlink $self->sheet or warn "Não foi possível remover " . $self->sheet;
  }
  return $self;
}

1;
