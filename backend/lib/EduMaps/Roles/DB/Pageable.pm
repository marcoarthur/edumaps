package EduMaps::Roles::DB::Pageable;
use Mojo::Base -role, -signatures;

requires qw(pager search_rs get_all);

has page_size => 10;
has _hidden_pager => sub ($self){ my $pager = $self->paginate->pager };

sub paginate($self) {
  return $self->search_rs(
    undef,
    {
      page => 1, 
      rows => $self->page_size,
    }
  );
}

sub set_page($self, $num) {
  die "Exceed total page" if $num > $self->total_pages;
  $self->_hidden_pager->current_page($num);
  $self;
}

sub set_page_size($self, $num) {
  $self->_hidden_pager->entries_per_page($num);
  $self;
}

sub get_page($self, $num) {
  die "Exceed total page" if $num > $self->total_pages;

  $self->_hidden_pager->current_page($num);
  $self->search_rs(
    undef,
    {
      page => $num,
      rows => $self->page_size,
    }
  )->get_all;
}

sub total_items($self) { $self->_hidden_pager->total_entries; }
sub total_pages($self) { $self->_hidden_pager->last_page }

sub get_iterator($self) {
  my $cur_page = 1;
  my $max = $self->total_pages;

  my $code = sub {
    return undef if $cur_page > $max;
    $self->_hidden_pager->current_page($cur_page);
    return $self->get_page($cur_page++);
  };

  return bless $code, 'EduMaps::PageIterator';
}

package EduMaps::PageIterator {
  sub next ($self) { return $self->(); }
}

sub to_api_response($self, $rows = undef) {
  return {
    data => $rows // $self->get_page($self->_hidden_pager->current_page),
    meta => {
      current_page => $self->_hidden_pager->current_page,
      per_page     => $self->_hidden_pager->entries_per_page,
      total_entries => $self->total_items,
      total_pages  => $self->total_pages,
    }
  };
}

1;
