#!/usr/bin/env perl

package EMEI::API {
  use Mojo::Base "Mojo::EventEmitter", -signatures, -async_await;
  use Getopt::Long;
  use lib qw(./lib);
  use Pod::Usage;
  use DateTime;
  use Syntax::Keyword::Try;
  use Mojo::URL;
  use Mojo::UserAgent;
  use IO::All;
  use utf8;
  use Mojo::JSON qw(encode_json);

  has base => sub {
    Mojo::URL->new('https://transparencia.educacao.sp.gov.br/Home/ListaDadosPddeJson');
  };
  has ua => sub { Mojo::UserAgent->new };

  sub _data($self, $code) {
    return {
      cdMunicipio => 0,
      cdDiretoria => 0,
      cdEscola => $code,
    };
  }

  async sub get_data_p($self, $escola) {
    my ($data, $tx);

    try {
      $tx = await $self->ua->get_p( $self->base->query( $self->_data($escola)->%* ) );
      $data = $tx->result->json;
    } catch ($err) {
      Mojo::Exception->throw("Erro acessando dados no site");
    }

    return $data;
  }

  sub get_data($self, $escola) {
    my $d;
    $self->get_data_p($escola)->then( sub ($data) { $d = $data } )->catch( sub($e) { warn "Error: $e" } )->wait;
    return $d;
  }

  sub get_and_save($self, $escola) {
    my $fname = "/tmp/data_escola_$escola.json";
    my $data  = $self->get_data($escola);
    io($fname)->print(encode_json($data));
    return $data;
  }

  1;
}

package main;
use DDP;
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $api = EMEI::API->new;

my $esc = 30806;
my $datum = $api->get_and_save($esc);

p $datum;

__END__
