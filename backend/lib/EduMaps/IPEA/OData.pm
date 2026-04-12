package EduMaps::IPEA::OData;

use strict;
use warnings;
use HTTP::Tiny;
use URI::Escape qw(uri_escape uri_unescape);
use JSON qw(decode_json);
use Carp qw(croak);

sub new {
    my ($class, %args) = @_;

    my $self = {
        base_url => $args{base_url} // 'https://www.ipeadata.gov.br/api/odata4',
        http     => HTTP::Tiny->new(
            timeout => $args{timeout} // 30,
        ),
    };

    return bless $self, $class;
}

# =========================
# Core HTTP layer
# =========================
sub _request {
    my ($self, $path, $query) = @_;

    my $url = $self->{base_url} . $path;

    if ($query && %$query) {
        my @pairs;
        for my $k (keys %$query) {
            push @pairs, uri_escape($k) . '=' . uri_escape($query->{$k});
        }
        $url .= '?' . join('&', @pairs);
    }

    my $res = $self->{http}->get($url);
    my $unescape = uri_unescape($url);
    $self->{last_request} = $url;

    croak "HTTP error: $res->{status} $res->{reason} URL: $unescape"
        unless $res->{success};

    my $data = decode_json($res->{content});

    return $data->{value} // $data;
}

# =========================
# Generic entity access
# =========================
sub entity {
    my ($self, $entity, %opts) = @_;

    my %query;

    $query{'$filter'}  = $opts{filter}  if $opts{filter};
    $query{'$select'}  = $opts{select}  if $opts{select};
    $query{'$orderby'} = $opts{orderby} if $opts{orderby};
    $query{'$top'}     = $opts{top}     if $opts{top};

    return $self->_request("/$entity", \%query);
}

# =========================
# Domain helpers
# =========================

sub metadados {
    my ($self, %opts) = @_;
    return $self->entity('Metadados', %opts);
}

sub valores {
    my ($self, %opts) = @_;

    croak "Missing SERCODIGO"
        unless $opts{sercodigo};

    my $filter = "SERCODIGO eq '$opts{sercodigo}'";

    if ($opts{date_from}) {
        $filter .= " and DATA ge '$opts{date_from}'";
    }

    if ($opts{date_to}) {
        $filter .= " and DATA le '$opts{date_to}'";
    }
    
    return $self->entity('Valores',
        filter  => $filter,
        $opts{top} ? (top => $opts{top}) : (),
        $opts{orderby} ? (orderby => $opts{orderby}) : (),
    );
}

sub search_metadados_text {
    my ($self, $text) = @_;

    my $filter = sprintf(
        q/contains(SERCOMENTARIO,'%s')/,
        $text,
    );

    return $self->metadados(
        filter => $filter,
    );
}

1;
