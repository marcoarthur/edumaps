use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';
use utf8;

# Testes específicos do buffer do EventLogger: flush por VOLUME (max_buffer)
# e o contrato do comando 'event_logger.flush' (retorna o nº persistido).

my $t   = Test::Mojo->new('EduMaps');
my $app = $t->app;

unless ($app->pg) {
  plan skip_all => 'Mojo::Pg não disponível para testes de integração';
}

my $db = $app->pg->db;

eval { $db->delete('event_store'); $db->delete('session_tracking') };
if ($@) {
  plan skip_all => 'Tabelas event_store/session_tracking ausentes. Execute as migrations do Sqitch.';
}

my $bulk_type = 'test.bulk.buffer';

sub flush_count {
  my $count = 0;
  $app->event_bus->request('event_logger.flush')
    ->then(sub { my ($n) = @_; $count = $n })
    ->wait;
  return $count;
}

subtest 'Flush automático por volume (max_buffer)' => sub {
  # 501 eventos -> o 500º dispara o flush; resta 1 no buffer.
  $app->event_bus->emit($bulk_type, { i => $_ }, source => 'T') for 1 .. 501;

  my $rows = $db->select('event_store', 'COUNT(*)', { event_type => $bulk_type })->array->[0];
  is $rows, 500, '500 eventos persistidos automaticamente ao atingir max_buffer';

  # Apostando no restante (1 evento) com flush manual
  my $left = flush_count();
  is $left, 1, 'flush manual devolve o nº de eventos restantes';

  my $total = $db->select('event_store', 'COUNT(*)', { event_type => $bulk_type })->array->[0];
  is $total, 501, 'todos os 501 eventos persistidos após o flush manual';
};

subtest 'Flush sem eventos no buffer não faz nada' => sub {
  is flush_count(), 0, 'flush vazio devolve 0';
};

END {
  if ($app->pg) {
    eval {
      $app->pg->db->delete('event_store', { event_type => $bulk_type });
      $app->pg->db->delete('event_store');
      $app->pg->db->delete('session_tracking');
    };
  }
}

done_testing();