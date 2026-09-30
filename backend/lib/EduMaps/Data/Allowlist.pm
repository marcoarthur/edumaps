package EduMaps::Data::Allowlist;

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

sub _load ($self) {
    state $cache = do {
        my $file = $self->file_path;
        -f $file ? LoadFile($file) : { sources => [], denied => [], sources_ref => [] };
    };
    return $cache;
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

    my $mojo_url = ref $url eq 'Mojo::URL' ? $url : Mojo::URL->new($url);
    my $host = $mojo_url->host;
    my $path = $mojo_url->path->to_string;
    $path = "/$path" unless $path =~ m{^/};

    # 1) Verificar se está explicitamente NEGADO
    for my $denied ($self->denied->@*) {
        next unless $denied->{host} eq $host;
        my $denied_path = $denied->{path};
        # Match simples: path começa com o negado (permite query params)
        if ($path =~ m{^\Q$denied_path\E}) {
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

    for my $src (@sources) {
        next unless $src->{host} eq $host;

        for my $res ($src->{resources}->@*) {
            my $res_path = $res->{path};
            # Match de path com placeholders {param}
            my $pattern = $res_path;
            $pattern =~ s/\{(\w+)\}/[^\/]+/g;  # {cod_mun} -> [^/]+
            $pattern = '^' . $pattern . '($|\/)';  # path exato ou prefixo

            if ($path =~ m{$pattern}i) {
                return 1;  # PERMITIDO
            }
        }
    }

    $self->last_error("Endpoint fora da allowlist: $host$path");
    return 0;
}

=head2 get_resource_info

    my $info = $allowlist->get_resource_info($url);

Retorna o hash do recurso permitido (com license, description) ou undef.

=cut

sub get_resource_info ($self, $url) {
    my $mojo_url = ref $url eq 'Mojo::URL' ? $url : Mojo::URL->new($url);
    my $host = $mojo_url->host;
    my $path = $mojo_url->path->to_string;
    $path = "/$path" unless $path =~ m{^/};

    for my $src ($self->sources->@*) {
        next unless $src->{host} eq $host;
        for my $res ($src->{resources}->@*) {
            my $pattern = $res->{path};
            $pattern =~ s/\{(\w+)\}/[^\/]+/g;
            $pattern = '^' . $pattern . '($|\/)';
            if ($path =~ m{$pattern}i) {
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