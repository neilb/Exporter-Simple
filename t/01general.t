#!/usr/bin/perl

use warnings;
use strict;
use lib 't/testlib';
use Test::More tests => 7;

# using askme(), which isn't exported by default,
# so need to import hello() as well

use MyExport qw($foo hello askme get_foo);

our $foo;
is($foo, 42, 'exported scalar');
$foo = 314;
is(get_foo(), $foo, 'exported sub get_foo()');
is(hello(), MyExport::hello(), 'exported sub hello()');
is(askme(), MyExport::askme(), 'exported sub askme()');
is($Exporter::ExportLevel, 0, 'ExportLevel properly localized');

is_deeply(\@MyExport::EXPORT, [ qw/$foo %baz hello get_foo/ ],
    '@MyExport::EXPORT');

is_deeply(\@MyExport::EXPORT_OK, [ qw/@bar askme hi get_bar/ ],
    '@MyExport::EXPORT_OK');
