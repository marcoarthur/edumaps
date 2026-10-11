package EduMaps::Schema::Result::CanalLista;
use Mojo::Base 'DBIx::Class::Core', -signatures;
use utf8;

# Lista nomeada de contatos da escola para autoinscrição via QR (issue #208).
# `clean.gestores`/`clean.contatos` não têm Result class neste projeto (acesso
# por SQL cru nas roles de negócio) — as FKs do banco permanecem, sem relação
# DBIC para essas tabelas.

__PACKAGE__->table('clean.canal_listas');
__PACKAGE__->add_columns(
  id         => { data_type => 'bigint', is_auto_increment => 1 },
  cod_inep   => { data_type => 'bigint', is_nullable => 0 },
  gestor_id  => { data_type => 'bigint', is_foreign_key => 1, is_nullable => 0 },
  nome       => { data_type => 'text', is_nullable => 0 },
  canal      => { data_type => 'text', is_nullable => 0, default_value => 'telefone' },
  descricao  => { data_type => 'text', is_nullable => 1 },
  ativo      => { data_type => 'boolean', is_nullable => 0, default_value => \'true' },
  created_at => { data_type => 'timestamptz', is_nullable => 0, default_value => \'now()' },
  updated_at => { data_type => 'timestamptz', is_nullable => 0, default_value => \'now()' },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw/cod_inep nome/]);

__PACKAGE__->has_many(qrcodes    => 'EduMaps::Schema::Result::CanalQrCode', 'lista_id',     { cascade_delete => 1 });
__PACKAGE__->has_many(membros    => 'EduMaps::Schema::Result::CanalListaMembro', 'lista_id', { cascade_delete => 1 });
__PACKAGE__->has_many(inscricoes => 'EduMaps::Schema::Result::CanalInscricao', 'lista_id',   { cascade_delete => 1 });

1;