#!/usr/bin/perl

use warnings;
use strict;
use lib qw(lib ./t/testlib);
use Test;

BEGIN { plan tests => 2 }

use MyExport qw(:greet);

ok(hello(), 'hello there');
ok(hi(),    'hi there');
