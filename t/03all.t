#!/usr/bin/perl

use warnings;
use strict;
use lib qw(lib ./t/testlib);
use Test;

BEGIN { plan tests => 2 }

# Trying the ':all' tag.
use MyExport qw(:all :DEFAULT);

ok(hello(), 'hello there');
ok(askme(), 'what you will');
