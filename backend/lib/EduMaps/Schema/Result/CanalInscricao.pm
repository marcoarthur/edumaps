package EduMaps::Schema::Result::CanalInscricao;
use Mojo::Base 'DBIx::Class::Core', -signatures;
use utf8;

# Proveniência/auditoria de cada submissão de autoinscrição (append-only).
# `qrcode_id` é nullable — refinamento da spec: revogamos QRs (ON DELETE SET
# NULL), nunca apagamos; o histórico permanece "sem descarte".

__PACKAGE__->table('clean.canal_inscricoes');
__PACKAGE__->add_columns(
  id                   => { data_type => 'bigint', is_auto_increment => 1 },
  qrcode_id            => { data_type => 'bigint', is_foreign_key => 1, is_nullable => 1 },
  lista_id             => { data_type => 'bigint', is_foreign_key => 1, is_nullable => 0 },
  contato_id           => { data_type => 'bigint', is_foreign_key => 1, is_nullable => 1 },
  nome                 => { data_type => 'text', is_nullable => 0 },
  telefone             => { data_type => 'text', is_nullable => 0 },
  telefone_norm        => { data_type => 'text', is_nullable => 0 },
  validado             => { data_type => 'boolean', is_nullable => 0, default_value => \'false' },
  duplicado_de         => { data_type => 'bigint', is_foreign_key => 1, is_nullable => 1 },
  conflito             => { data_type => 'boolean', is_nullable => 0, default_value => \'false' },
  ip_anon              => { data_type => 'text', is_nullable => 1 },
  user_agent           => { data_type => 'text', is_nullable => 1 },
  consentimento_em     => { data_type => 'timestamptz', is_nullable => 0 },
  consentimento_versao => { data_type => 'text', is_nullable => 0 },
  created_at           => { data_type => 'timestamptz', is_nullable => 0, default_value => \'now()' },
);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(lista  => 'EduMaps::Schema::Result::CanalLista',  'lista_id');
__PACKAGE__->belongs_to(qrcode => 'EduMaps::Schema::Result::CanalQrCode', 'qrcode_id');
# `contato_id`/`duplicado_de` referenciam clean.contatos, que não tem Result
# class neste projeto (acesso por SQL cru nas roles de negócio) — a FK do banco
# permanece, sem relação DBIC.

1;