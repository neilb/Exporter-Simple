#!/usr/bin/perl

use warnings;
use strict;
use lib qw(lib ./t/testlib);
use Test;

BEGIN { plan tests => 5 }

use MyExport qw(:globals);

ok(EXPORTED_CONST, 47632);
ok(EXPORTABLE_CONST, 52611);
ok($friend, 'here');
ok(scalar @array, 6);
ok($array[2], 4);
