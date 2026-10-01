package EduMaps::Ingestion::Jobs;
use Mojo::Base -base, -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use Mojo::Promise;
use Mojo::JSON qw(true false);
use Mojo::Collection;
use Text::CSV;
use DateTime;
use DateTime::Format::ISO8601;

# This file contains all ingestion job classes.
# Each job is a proper package with Mojo::Base inheritance.

1;