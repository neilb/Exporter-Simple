package MyExport;

use warnings;
use strict;
use Exporter::Simple;

our $VERSION = '0.01';

use vars '@array';
@array = (1, 2, 4, 8, 16, 32);
use constant EXPORTED_CONST => 47632;

no warnings 'once';
our $friend = 'here';

# red herring for Exporter::Simple's source filter
1;

use constant EXPORTABLE_CONST => 52611;

our $custom_import = '';
sub import { our $custom_import = 'been'; }
sub been_to_import :Exported { our $custom_import };

BEGIN {
	export([ qw/EXPORTED_CONST @array $friend/ ], 'globals');
	exportable('EXPORTABLE_CONST', 'globals');
}

my @bar : Exportable(vars) = (2, 3, 5, 7);
my $foo : Exported(vars)   = 42;
my %baz : Exported         = (a => 65, b => 66);

sub hello : Exported(greet,uk)   { "hello there" }
sub askme : Exportable           { "what you will" }
sub hi    : Exportable(greet,us) { "hi there" }

sub get_foo :Exported(vars) { $foo }
sub get_bar :Exportable(vars) { @bar }

1; # don't forget to return a true value

__END__

This is probably where the documentation would go.

