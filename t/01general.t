#!/usr/bin/perl

use warnings;
use strict;
use lib qw(lib ./t/testlib);
use Test;

BEGIN { plan tests => 5 }

# using askme(), which isn't exported by default,
# so need to import hello() as well
use MyExport qw(hello askme get_foo);

ok($foo, 42);
$foo = 314;
ok(get_foo(), 314);
ok(hello(), 'hello there');
ok(askme(), 'what you will');
ok($Exporter::ExportLevel, 0);   # properly localized?
