package EduMaps::R::Pipe;
use Mojo::Base "Mojo::EventEmitter", -signatures, -async_await;
use EduMaps::R::Script;
use Mojo::Template;
use Mojo::File qw(tempfile);
use Mojo::Loader qw(data_section);
use constant {
  DEBUG => $ENV{R_PIPE_DEBUG},
};
#use Syntax::Keyword::Try;

has _input    => sub { tempfile};
has _output   => sub { tempfile };
has _results  => sub { die "No result found" };
has _error    => sub { tempfile };
has data      => sub { die 'Requires a resultset data' };
has vars      => sub { +{} };
has __scripts => sub { 
  my $files = data_section __PACKAGE__;
  my %map;
  for my $k (keys %$files) {
    (my $name = $k) =~ s/\..*$//;
    $map{$name} = $files->{$k};
  }
  \%map;
};

# defaults for each plot
has _defaults_vars => sub {
  my %common = (
    width  => 2700,
    height => 1800,
    format => 'svg',
    xlab   => 'x label',
    ylab   => 'y label',
    dpi     => 300,
  );
  return {
    scatterplot => {
      %common,
      color   => undef,
      alpha   => 0.7,
      size    => 2,
      format  => 'svg',
      title   => 'scatterplot',
    },
    histogram => {
      %common,
      bins => 30,
      title  => 'histogram',
    },
    barplot => {
      %common,
      fill => undef,
      rotate_x => 45,
      ylab => 'Total',
      title => 'barplot',
    }
  };
};
has keep_output => sub { 1 };
has script => sub {
  EduMaps::R::Script->new(engine => 'Rscript');
};
has template  => sub { 
  Mojo::Template->new->vars(1); 
};
has _script_file => sub { tempfile };
has save_at => sub { undef };

sub new($class, @args) {
  $class = ref $class ? ref $class : $class;
  my $self= $class->SUPER::new(@args);
  $self->on( 
    debug => sub ($evt, $info) { 
      warn sprintf "step: %s\ninfo: %s", $info->[0], $info->[1] 
    } 
  ) if DEBUG;
  $self;
}

sub run($self, $script, %vars) {
  my $r_script = $self->__scripts->{$script};
  die "Cannot find $script to run" unless $r_script;

  # variables in order of importance: function argument, object creation and defaults.
  $self->vars->%* = ($self->_defaults_vars->{$script}->%*, $self->vars->%*, %vars);
  $self->save_at(Mojo::File->new($self->vars->{save_at})) if $self->vars->{save_at};

  $self->_prepare_input
  ->_prepare_script($r_script)
  ->_execute_r
  ->_collect_output;

  if ( my $err = $self->_error->slurp ) {
    $self->emit( error => $err );
    die sprintf("Error: %s", $err);
  } else {
    $self->save_at->spew($self->_output->slurp) if $self->save_at;
    return $self->_output;
  }
}

sub _prepare_input ($self) {
  $self->_input->spew($self->data->to_csv);
  $self->emit( after_csv => $self->_input );
  $self->vars->{input}  = $self->_input->path;
  $self->vars->{output} = $self->_output->path;
  $self;
}

sub _prepare_script($self, $script_content) {
  my $rendered = $self->template->render(
    $script_content,
    $self->vars,
  );
  $self->_script_file->spew($rendered);
  $self->emit( debug => ['script', $rendered] );
  $self->vars->{script_file} = $self->_script_file->path;
  $self;
}

sub _execute_r($self) {
  $self->emit( before_run => $self->_script_file );
  $self->script->script($self->_script_file);
  $self->script->error($self->_error);
  $self->script->output($self->_output);
  $self->script->execute->wait;
  $self->emit( after_run => $self->_output );
  $self;
}

sub _collect_output($self) {
  $self->_results($self->_output);
  $self;
}

sub DESTROY ($self) {
  for my $attr (qw(_input _script_file _error)) {
    my $f = eval { $self->$attr } or next;
    $f->remove if -e $f;
  }
  $self->_output->remove unless $self->keep_output;
}

1;

__DATA__

@@ histogram.R.ep
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

data <- read_csv("<%= $input %>", show_col_types = FALSE)

p <- ggplot(data, aes(x = .data[["<%= $x %>"]])) +
  geom_histogram(
    bins = <%= $bins // 30 %>,
    fill = "steelblue",
    color = "white"
  ) +
  labs(
    title = "<%= $title // '' %>",
    x     = "<%= $xlab  // $x %>",
    y     = "<%= $ylab  // 'Frequency' %>"
  ) +
  theme_minimal()

ggsave(
  filename = "<%= $output %>",
  plot     = p,
  width    = <%= $width  %> / <%= $dpi %>,
  height   = <%= $height %> / <%= $dpi %>,
  dpi      = <%= $dpi // 72 %>,
  device   = <%= $format // 'png' %>
)

@@ scatterplot.R.ep
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

data <- read_csv("<%= $input %>", show_col_types = FALSE)

p <- ggplot(
  data,
  aes(
    x = .data[["<%= $x %>"]],
    y = .data[["<%= $y %>"]]
<% if ($color) { %>
    , color = .data[["<%= $color %>"]]
<% } %>
  )
) +
  geom_point(
    alpha = <%= $alpha // 0.7 %>,
    size  = <%= $size  // 2 %>
  ) +
  labs(
    title = "<%= $title // '' %>",
    x     = "<%= $xlab  // $x %>",
    y     = "<%= $ylab  // $y %>"
  ) +
  theme_minimal()

ggsave(
  filename = "<%= $output %>",
  plot     = p,
  width    = <%= $width  %> / <%=$dpi%>,
  height   = <%= $height %> / <%=$dpi%>,
  dpi      = <%= $dpi %>,
  device   = <%= $format // 'png' %>
)

@@ barplot.R.ep
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

data <- read_csv("<%= $input %>", show_col_types = FALSE)

p <- ggplot(
  data,
  aes(x = .data[["<%= $x %>"]]
<% if ($fill) { %>
    , fill = .data[["<%= $fill %>"]]
<% } %>
  , y = .data[["<%= $y %>"]]
  )
) +
  geom_bar(stat = "identity") +
  labs(
    title = "<%= $title // '' %>",
    x     = "<%= $xlab  // $x %>",
    y     = "<%= $ylab  // 'Count' %>"
  ) +
  theme_minimal()

<% if ($rotate_x) { %>
p <- p + theme(
  axis.text.x = element_text(
    angle = <%= $rotate_x %>,
    hjust = 1
  )
)
<% } %>

ggsave(
  filename = "<%= $output %>",
  plot     = p,
  width    = <%= $width  %> / <%=$dpi%>,
  height   = <%= $height %> / <%=$dpi%>,
  dpi      = <%= $dpi %>,
  device   = <%= $format // 'png' %>
)
