#!/usr/bin/perl

use warnings;
use strict;
use lib qw(lib ./t/testlib);
use Test;

BEGIN { plan tests => 2 }

# only using default imports
use MyExport;

ok(hello(), 'hello there');
ok(been_to_import(), 'been');
