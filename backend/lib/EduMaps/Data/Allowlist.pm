package EduMaps::Data::Allowlist;
use utf8;

=head1 NAME

EduMaps::Data::Allowlist - Validador de allowlist de endpoints para ingestão

=head1 SYNOPSIS

    use EduMaps::Data::Allowlist;

    my $allowlist = EduMaps::Data::Allowlist->new;
    $allowlist->validate_url('https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do')
        or die "Endpoint não permitido: " . $allowlist->last_error;

=head1 DESCRIPTION

Carrega C<data_pipeline/allowlist.yaml> e valida se uma URL está na lista
de endpoints/recursos permitidos. A validação acontece ANTES da requisição
HTTP — endpoint fora da lista aborta o job com erro explícito.

A lista distingue entre:
- C<sources>: fontes com recursos permitidos (por host + path)
- C<denied>: recursos EXPLICITAMENTE negados (mesmo host de permitido, mas sensível)

Fonte com C<status: inativo> (host morto, API retirada) fica no arquivo como
histórico, mas as URLs dela são REJEITADAS.

O carregamento FALHA ALTO (C<die>) se o arquivo:
- tiver chave de topo duplicada (o YAML::XS não acusa e fica com a última
  ocorrência — issue #230: 8 fontes e todo o C<denied> ficaram inertes);
- não for um mapa, ou se C<sources>/C<denied> faltarem ou não forem listas
  (C<sources_ref>, se existir, também tem de ser lista);
- tiver fonte sem C<id>/C<host>, ou C<id> de fonte (ou de C<denied>) repetido.

=cut

use Mojo::Base -base, -signatures;
use Mojo::File qw(path);
use Mojo::URL;
use YAML::XS qw(LoadFile);
use Carp qw(croak);

has file_path => sub ($self) {
    # Tenta vários locais: cwd, projeto, instalado
    for my $p (
        'data_pipeline/allowlist.yaml',
        '../data_pipeline/allowlist.yaml',
        '../../data_pipeline/allowlist.yaml',
    ) {
        return $p if -f $p;
    }
    croak "allowlist.yaml não encontrado em data_pipeline/";
};

has sources   => sub ($self) { $self->_load->{sources}   // [] };
has denied    => sub ($self) { $self->_load->{denied}    // [] };
has sources_r => sub ($self) { $self->_load->{sources_ref} // [] };
has last_error => '';

# Cache por caminho de arquivo (antes era um `state` único, que devolvia o
# primeiro arquivo carregado no processo para QUALQUER file_path).
my %CACHE;

sub _load ($self) {
    my $file = $self->file_path;
    return $CACHE{$file} //= _load_file($file);
}

# Carrega e valida o YAML. Morre com mensagem clara em qualquer problema
# de estrutura — allowlist inválida não pode degradar em "tudo negado" ou,
# pior, em "denied vazio" sem ninguém perceber.
sub _load_file ($file) {
    croak "allowlist: arquivo não encontrado: $file" unless -f $file;

    _check_duplicate_top_keys($file);

    my $data = LoadFile($file);
    croak "allowlist $file: o topo do YAML tem de ser um mapa (sources/denied/sources_ref)"
        unless ref $data eq 'HASH';

    for my $key (qw(sources denied)) {
        croak "allowlist $file: chave de topo '$key' ausente"
            unless exists $data->{$key};
        croak "allowlist $file: '$key' tem de ser uma lista (veio "
            . (ref $data->{$key} || (defined $data->{$key} ? 'escalar' : 'vazio')) . ')'
            unless ref $data->{$key} eq 'ARRAY';
    }
    $data->{sources_ref} //= [];
    croak "allowlist $file: 'sources_ref' tem de ser uma lista"
        unless ref $data->{sources_ref} eq 'ARRAY';

    my %seen;
    for my $i (0 .. $#{ $data->{sources} }) {
        my $src = $data->{sources}[$i];
        croak "allowlist $file: sources[$i] não é um mapa" unless ref $src eq 'HASH';
        croak "allowlist $file: sources[$i] sem 'id'"   unless length($src->{id}   // '');
        croak "allowlist $file: fonte '$src->{id}' sem 'host'" unless length($src->{host} // '');
        croak "allowlist $file: id de fonte duplicado: '$src->{id}'" if $seen{ $src->{id} }++;
        $src->{resources} //= [];
        croak "allowlist $file: fonte '$src->{id}': 'resources' tem de ser uma lista"
            unless ref $src->{resources} eq 'ARRAY';
    }

    my %seen_denied;
    for my $i (0 .. $#{ $data->{denied} }) {
        my $den = $data->{denied}[$i];
        croak "allowlist $file: denied[$i] não é um mapa" unless ref $den eq 'HASH';
        for my $f (qw(id host path)) {
            croak "allowlist $file: denied[$i] sem '$f'" unless length($den->{$f} // '');
        }
        croak "allowlist $file: id de denied duplicado: '$den->{id}'" if $seen_denied{ $den->{id} }++;
    }

    return $data;
}

# O YAML::XS aceita chave de mapa duplicada em silêncio. Varre as linhas de
# topo (sem indentação, fora de comentário) e acusa repetição.
sub _check_duplicate_top_keys ($file) {
    my @lines = split /\n/, path($file)->slurp;
    my %first;
    for my $n (1 .. @lines) {
        my $line = $lines[ $n - 1 ];
        next unless $line =~ /^([A-Za-z_][\w-]*)\s*:/;
        my $key = $1;
        croak "allowlist $file: chave de topo '$key' duplicada (linhas $first{$key} e $n). "
            . "O YAML ficaria só com a última ocorrência; unifique os blocos."
            if $first{$key};
        $first{$key} = $n;
    }
    return 1;
}

sub _is_active ($src) {
    return lc($src->{status} // 'ativo') ne 'inativo';
}

# Converte o path declarado num regex ancorado no início.
#   {param} -> um segmento; "*" -> qualquer trecho sem "/"; resto literal.
# $prefix_only: casa qualquer path que comece com o padrão (usado em denied);
# senão, path exato ou seguido de "/". Antes o path entrava cru no regex
# ("." casava qualquer caractere e "_*" virava "zero ou mais _").
sub _path_regex ($declared, $prefix_only = 0) {
    my $re = join '', map {
          /^\{\w+\}$/ ? '[^/]+'
        : $_ eq '*'     ? '[^/]*'
        :                 quotemeta($_)
    } grep { length } split /(\{\w+\}|\*)/, $declared;
    # Path declarado terminado em "/" (ex.: "/") já é fronteira de segmento.
    return ($prefix_only || $declared =~ m{/\z}) ? qr{^$re}i : qr{^$re(?:\z|/)}i;
}

sub _url_parts ($url) {
    my $mojo_url = ref $url eq 'Mojo::URL' ? $url : Mojo::URL->new($url);
    my $host = $mojo_url->host // '';
    my $path = $mojo_url->path->to_string;
    $path = "/$path" unless $path =~ m{^/};
    return ($host, $path);
}

=head2 validate_url

    my $ok = $allowlist->validate_url($url);
    # ou
    my $ok = $allowlist->validate_url($url, $source_id);

Valida se a URL está na allowlist. Se C<$source_id> for fornecido, valida
apenas contra aquela fonte.

Retorna verdadeiro se permitido, falso se negado (define C<last_error>).

=cut

sub validate_url ($self, $url, $source_id = undef) {
    $self->last_error('');

    my ($host, $path) = _url_parts($url);

    # 1) Verificar se está explicitamente NEGADO (precede qualquer permissão)
    for my $denied ($self->denied->@*) {
        next unless lc $denied->{host} eq lc $host;
        if ($path =~ _path_regex($denied->{path}, 1)) {
            $self->last_error(
                "Endpoint explicitamente NEGADO: $host$path (" . ($denied->{reason} // 'sem motivo') . ")"
            );
            return 0;
        }
    }

    # 2) Se source_id fornecido, validar apenas contra aquela fonte
    my @sources = $source_id
        ? grep { $_->{id} eq $source_id } $self->sources->@*
        : $self->sources->@*;

    my $inactive;
    for my $src (@sources) {
        next unless lc $src->{host} eq lc $host;

        for my $res ($src->{resources}->@*) {
            next unless $path =~ _path_regex($res->{path});
            return 1 if _is_active($src);    # PERMITIDO
            $inactive //= $src;
        }
    }

    if ($inactive) {
        $self->last_error(
            "Fonte INATIVA na allowlist ($inactive->{id}): $host$path ("
            . ($inactive->{status_note} // 'host/API desativado') . ")"
        );
        return 0;
    }

    $self->last_error("Endpoint fora da allowlist: $host$path");
    return 0;
}

=head2 get_resource_info

    my $info = $allowlist->get_resource_info($url);

Retorna o hash do recurso permitido (com license, description) ou undef.
Fontes inativas não contam.

=cut

sub get_resource_info ($self, $url) {
    my ($host, $path) = _url_parts($url);

    for my $src ($self->sources->@*) {
        next unless _is_active($src);
        next unless lc $src->{host} eq lc $host;
        for my $res ($src->{resources}->@*) {
            if ($path =~ _path_regex($res->{path})) {
                return {
                    source_id   => $src->{id},
                    source_name => $src->{name},
                    resource    => $res,
                };
            }
        }
    }
    return undef;
}

=head2 get_license_for_url

    my $license = $allowlist->get_license_for_url($url);

Retorna a licença (SPDX) declarada para o recurso, ou "Não verificada".

=cut

sub get_license_for_url ($self, $url) {
    my $info = $self->get_resource_info($url);
    return $info ? ($info->{resource}{license} // 'Não verificada') : 'Não verificada';
}

1;