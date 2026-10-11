# t/03-plugins/channel/history.t
# Histórico de mensagens de canal: ciclo queued -> sent/failed, listagem com
# filtros e máscara de PII na leitura. Só roda onde a migration canal_mensagens
# foi aplicada.
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';

use EduMaps::Schema;
use EduMaps::Channel::History;

my $schema = eval { EduMaps::Schema->go };
plan skip_all => 'base indisponível: ' . ($@ // '?') unless $schema;

my $dbh = $schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_mensagens')");
plan skip_all => 'clean.canal_mensagens ausente (migration não aplicada)' unless $has;

my $hist = EduMaps::Channel::History->new(schema => $schema);
my @IDS;

END {
  return unless $schema && $has && @IDS;
  my $dbh = $schema->storage->dbh;
  local $dbh->{RaiseError} = 0;
  $dbh->do('DELETE FROM clean.canal_mensagens WHERE id = ANY(?::bigint[])', {},
    '{' . join(',', @IDS) . '}');
}

subtest 'queued -> sent' => sub {
  my $id = $hist->queued({
    canal => 'email', operacao => 'aviso', to => 'dest@exemplo.com',
    assunto => 'Oi', corpo => 'Corpo', referente => { tipo => 'reuniao', id => 7 },
  });
  push @IDS, $id;
  ok $id > 0, 'id devolvido';

  my $row = $dbh->selectrow_hashref('SELECT * FROM clean.canal_mensagens WHERE id = ?', {}, $id);
  is $row->{status}, 'queued', 'status queued';
  is $row->{operacao}, 'aviso', 'operação';
  is $row->{referente_tipo}, 'reuniao', 'referente tipo';
  is $row->{referente_id}, 7, 'referente id';
  is $row->{destinatario}, 'dest@exemplo.com', 'destinatário';

  $hist->sent($id, { provider_message_id => 'mid-9' });
  $row = $dbh->selectrow_hashref('SELECT * FROM clean.canal_mensagens WHERE id = ?', {}, $id);
  is $row->{status}, 'sent', 'status sent';
  is $row->{provider_message_id}, 'mid-9', 'provider id';
  ok defined $row->{sent_at}, 'sent_at preenchido';
  is $row->{tentativas}, 1, 'tentativas';
};

subtest 'failed guarda o erro' => sub {
  my $id = $hist->queued({
    canal => 'whatsapp', operacao => 'pedido', to => '5511999990001', corpo => 'x',
  });
  push @IDS, $id;
  $hist->failed($id, { error => 'sem rede' });
  my $row = $dbh->selectrow_hashref('SELECT * FROM clean.canal_mensagens WHERE id = ?', {}, $id);
  is $row->{status}, 'failed', 'status failed';
  is $row->{erro}, 'sem rede', 'erro guardado';
};

subtest 'list com máscara de PII' => sub {
  my $id = $hist->queued({
    canal => 'email', operacao => 'convite', to => 'maria.silva@exemplo.com', corpo => 'segredo',
  });
  push @IDS, $id;

  my $rows = $hist->list({ canal => 'email', mask => 1, limite => 100 });
  my ($mine) = grep { $_->{id} == $id } @$rows;
  ok $mine, 'linha presente na listagem';
  is $mine->{destinatario}, 'ma*********@exemplo.com', 'e-mail mascarado';
  is $mine->{corpo}, '[conteúdo restrito]', 'corpo mascarado';
};

subtest 'list sem máscara devolve cru (uso interno/restrito)' => sub {
  my $id = $hist->queued({ canal => 'email', operacao => 'informacao', to => 'joao@exemplo.com' });
  push @IDS, $id;
  my $rows = $hist->list({ canal => 'email' });
  my ($mine) = grep { $_->{id} == $id } @$rows;
  is $mine->{destinatario}, 'joao@exemplo.com', 'destinatário cru';
};

subtest 'mask_address' => sub {
  is $hist->mask_address('maria@exemplo.com'), 'ma***@exemplo.com', 'e-mail';
  is $hist->mask_address('5511999990001'), '*********0001', 'telefone';
  is $hist->mask_address('-100'), '-100', 'curto intacto';
};

done_testing;
