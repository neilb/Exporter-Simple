#!/usr/bin/perl

use warnings;
use strict;
use lib qw(lib ./t/testlib);
use Test;

BEGIN { plan tests => 6 }

use MyExport qw(:vars);

ok($foo, 42);
$foo = 314;
ok(get_foo(), 314);

ok(scalar @bar, 4);
ok($bar[2], 5);
push @bar => 11, 13;
my @newbar = get_bar();
ok(scalar @newbar, 6);
ok($newbar[-1], 13);
