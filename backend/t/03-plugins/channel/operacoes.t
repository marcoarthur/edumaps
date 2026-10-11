# t/03-plugins/channel/operacoes.t
# Operações (motivo) de uma mensagem de canal: whitelist espelhada no CHECK de
# clean.canal_mensagens.operacao.
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Channel::Operacoes';

my $ops = EduMaps::Channel::Operacoes->available;
ok ref($ops) eq 'ARRAY', 'available devolve arrayref';
ok scalar(@$ops) >= 6, 'pelo menos 6 operações';

for my $op (@$ops) {
  ok(EduMaps::Channel::Operacoes->is_valid($op), "válida: $op");
}

ok(!EduMaps::Channel::Operacoes->is_valid('inventada'), 'inválida recusada');
ok(!EduMaps::Channel::Operacoes->is_valid(undef),       'undef recusado');
ok(!EduMaps::Channel::Operacoes->is_valid(''),          'vazio recusado');
ok(!EduMaps::Channel::Operacoes->is_valid([]),          'ref recusada');

done_testing;
