package Exporter::Simple;

use warnings;
use Attribute::Handlers;

# Load Exporter.pm so it's available to users of Exporter::Simple.
# It's already there via Carp via Attribute::Handlers, but still:
require Exporter;

use Filter::Simple;

# Filter::Simple, naughtily, clobbers caller's (i.e., Exporter::Simple's
# in this case), import() and unimport(). To prevent that, we replicate
# what Filter::Simple::import does, assign it to a different sub name and
# call that sub at the end of our own import().

*filter_import = Filter::Simple::gen_filter_import(__PACKAGE__, sub
{
	# lexicals aren't in scope in this module, only at the top
	# level of the module that declares (and wants to export)
	# them, so we munge that module's source to make a note of
	# all lexicals. This will be used to get a reference to them
	# later. BEGIN blocks are run when encountered in the source,
	# so any lexicals declared *after* the block won't be in the
	# pad yet. So we have to insert the block as late as possible.
	# So we expect the module author to stick to the convention
	# of using "1;" on a line by itself (possibly followed by a
	# comment) to return a true value from the module; we take
	# this to mean that there are no more declarations after
	# that.

	my $code =<<'EOCODE';
    BEGIN {
	    use PadWalker;
	    my $h = PadWalker::peek_my(0);
	    while (my ($n, $v) = each %$h) {
		    $Exporter::Simple::lexlookup{+__PACKAGE__}{"$v"} = $n
	    }
    }

    1;
EOCODE

	# expect a "1;" line (with an optional comment at the end)
	# near the end of the module and replace it with the
	# lexical-inspecting code

	s/(.*) ^ \s* 1 \s* ; \s* (\# .* )? $/$1$code/msx;

	s/sub\s*import\s*{/sub __custom_import_666 {/gs;
});

# unimport() can be clobbered, as we don't have a custom one.
sub unimport {
    &Filter::Simple::unimport;
    &Attribute::Handlers::unimport;
}

our $VERSION = '0.13';

sub lexlookup {
	# lookup a lexical reference to get the lexical's name
	# The information was built up during caller's BEGIN generated
	# by the source filter above.

	my ($lex, $pkg) = @_;
	our (%lexlookup, %is_globbed);
	my $symbol = $lexlookup{$pkg}{"$lex"} || $lex;

	# alias the lexical reference to a glob the first time we see it
	unless ($is_globbed{$symbol}++) {
		(my $varname = $symbol) =~ y/$@%//d;
		*{"${pkg}::$varname"} = $lex;
	}

	return $symbol;
}

sub import {
	my $pkg = (caller)[0];
        return if $pkg eq __PACKAGE__;

	# install an import routine in the calling package
	# which will make a note of the symbols it is expected
	# to export, then handle lexical exports.
	# This is the only place we can handle lexical exports.

	*{"${pkg}::export"} = *export;
	*{"${pkg}::exportable"} = *exportable;

	*{"${pkg}::import"} = sub {
		my $pkg = shift;
		$Exporter::Simple::wantimport{$pkg} = [ @_ ];

		no warnings 'once';   # lexlookup

		# in the whole %export structure, make refs into symbols
		# %export also contains global variable export definitions
		# (from 'our'), so only makes those refs into symbols that
		# look like a ref when stringified, e.g., 'SCALAR(0x23147c)'

		my $def = $Exporter::Simple::export{begin}{$pkg};
		$_ = Exporter::Simple::lexlookup($_, $pkg) for
		    grep { /(SCALAR|ARRAY|HASH)\(0x.*?\)/ }
		    @{ $def->{EXPORT} };

		my $deftags = $def->{EXPORT_TAGS};
		for my $tag (keys %$deftags) {
			$_ = Exporter::Simple::lexlookup($_, $pkg) for
			    grep { /(SCALAR|ARRAY|HASH)\(0x.*?\)/ }
			    @{ $deftags->{$tag} };
		}

		#use Data::Dumper; print Dumper(\%Exporter::Simple::export);

		# now copy the export structures to the variables Exporter
		# expects

		local $Exporter::ExportLevel = 1;
		@{"${pkg}::EXPORT"} = @{ $def->{EXPORT} };
		%{"${pkg}::EXPORT_TAGS"} = %$deftags;
		@{"${pkg}::EXPORT_OK"} = @{ $deftags->{all} || [] };

		# only ask Exporter to export variable names and tags.
		Exporter::import($pkg,
		    grep { /^[^a-zA-Z_]/ } @{$wantimport{$pkg} || []});

		# reset the arrays so subs can be exported cleanly later
		@{"${pkg}::EXPORT"} = ();
		%{"${pkg}::EXPORT_TAGS"} = ();
		@{"${pkg}::EXPORT_OK"} = ();

		# A hash that's built up by Exporter; need to clear it as well
		# as Exporter uses it as a cache of tags and symbols (AFAIK).
		# If we don't clear it here, then during the subroutine symbol
		# exports in INIT() below, it won't recognize subs in tags
		# we've already defined here. (And we can't export the subs
		# here because at BEGIN time they don't yet have a symbol
		# table entry and we can't get it's name. Sigh.)

		%{"${pkg}::EXPORT"} = ();

		# now do a custom import, if it is defined
		( *{"${pkg}::__custom_import_666"}{CODE} || sub {} ) -> (@_);


	};

	filter_import(@_);
}

sub mark_tags {

	# make empty entries for all tags defined by subroutine
	# attributes, as they are still needed when exporting
	# variables. For example, if you have a ':subs' tag that
	# only consists of subs and no variables, Exporter will still
	# be asked to export all symbols in ':subs' during caller's
	# import (see above). But unless we indicate that it exists,
	# Exporter won't find it in the lexical's %EXPORT_TAGS and
	# will fail.
	#
	# The actual symbol will be exported in our INIT() below.
	#
	# And vice versa: Tags with only variable definitions still
	# need to be in caller's %EXPORT_TAGS during subroutine
	# symbol exports in INIT() below.

	my ($pkg, $tags) = @_;
	$tags = [ $tags || () ] unless ref $tags eq 'ARRAY';
	
	our %export;
	for my $symtype (qw/begin init/) {
		push @{ $export{$symtype}{$pkg}{EXPORT_TAGS}{$_} } => ()
		    for @$tags;
	}
}

# exported() and exportable() are for globals, as they can't take
# attributes. Need to be called during BEGIN, though...

sub export {
	# manually export one or more symbols
	my ($symbols, $tags) = @_;
	my $pkg = (caller)[0];

	$symbols = [ $symbols || () ] unless ref $symbols eq 'ARRAY';
	$tags = [ $tags || () ] unless ref $tags eq 'ARRAY';
	mark_tags($pkg, $tags);

	for my $symbol (@$symbols) {
		prepare_export('begin', $pkg, $symbol, $tags);
		push @{ $export{begin}{$pkg}{EXPORT} } => $symbol;
	}
}

sub exportable {
	# manually make one or more symbols exportable
	# could just call export here, but it messes up caller()

	my ($symbols, $tags) = @_;
	my $pkg = (caller)[0];

	$symbols = [ $symbols || () ] unless ref $symbols eq 'ARRAY';
	$tags = [ $tags || () ] unless ref $tags eq 'ARRAY';
	mark_tags($pkg, $tags);
	
	for my $symbol (@$symbols) {
		prepare_export('begin', $pkg, $symbol, $tags);
	}
}

sub prepare_export {
	my ($symtype, $pkg, $symbol, $tags) = @_;
	$tags = [ $tags || () ] unless ref $tags eq 'ARRAY';

	# add the symbol to $EXPORT_TAGS{'all'}, since the :all tag
	# will be added later (in INIT) to @EXPORT_OK automatically.
	# this is in accordance to the standard way h2xs suggests.

	our %export;
	push @{ $export{$symtype}{$pkg}{EXPORT_TAGS}{all} } => $symbol;

	# add the ref to all specified export tags
	push @{ $export{$symtype}{$pkg}{EXPORT_TAGS}{$_} } => $symbol for @$tags;
}

sub handler {
	my ($pkg, $symbol, $ref, $attr, $tags, $phase) = @_;
	$symbol = *{$symbol}{NAME} if ref $symbol;

	# at BEGIN, subroutines aren't defined yet are therefore passed as
	# 'ANON', so we skip those - we'll see them again during CHECK.

	mark_tags($pkg, $tags);
	return if $symbol eq 'ANON';
	our %is_lexical;

	if ($symbol eq 'LEXICAL' && $phase eq 'BEGIN') {
		# remember it by reference so it can be weeded out during
		# CHECK, see below
		$is_lexical{$ref} = 1;

		# marking lexical $ref for export to $pkg
		prepare_export('begin', $pkg, $ref, $tags);
		our %export;
		push @{ $export{begin}{$pkg}{EXPORT} } => $ref
		    if $attr eq 'Exported';
        }
	return if $symbol eq 'LEXICAL';   # BEGIN or CHECK

	# during CHECK, the symbol names are given as well (no longer
	# 'LEXICAL'), but of course that's too late for our purposes.
	# Still, we've already exported variables during BEGIN, so weed
	# them out here to allow only subroutine exports here.

	return if $is_lexical{$ref};

	# still here? gotta be a subroutine export during CHECK, then

	$symbol =~ s/^\*${pkg}:://;
	prepare_export('init', $pkg, $symbol, $tags);
	push @{ $export{init}{$pkg}{EXPORT} } => $symbol
	    if $attr eq 'Exported';
}

sub UNIVERSAL::Exported   :ATTR(BEGIN,CHECK) { &handler }
sub UNIVERSAL::Exportable :ATTR(BEGIN,CHECK) { &handler }

INIT {
	# don't import into the neo-exporting package, but the one calling it.
	# localize it so modules further ahead don't get a nasty surprise.
	local $Exporter::ExportLevel = 2;

	# manually trigger the import process, as this is normally done during
	# INIT; but these attributes are processed during CHECK to gather
	# information; then the symbols are summarily exported here.

	# import() is called with the usual semantics per Exporter: if
	# there are no args, the default exports are imported (i.e., @EXPORT);
	# otherwise only the specified symbols from @EXPORT and @EXPORT_OK
	# are imported.

	our (%export, %wantimport);

	for my $pkg (keys %{ $export{init} }) {
		my $def = $export{init}{$pkg};
		my $deftags = $def->{EXPORT_TAGS};
                @{"${pkg}::EXPORT"} = @{ $def->{EXPORT} || [] };
		%{"${pkg}::EXPORT_TAGS"} = %$deftags;
		@{"${pkg}::EXPORT_OK"} = @{ $deftags->{all} || [] };
		Exporter::import($pkg,
		    grep { !/^[\$\@\%]/ } @{$wantimport{$pkg} || []});
	}
}

1;

__END__

=head1 NAME

Exporter::Simple - Easier set-up of module exports

=head1 SYNOPSIS

  package MyExport;
  use Exporter::Simple;

  my @bar : Exportable(vars) = (2, 3, 5, 7);
  my $foo : Exported(vars)   = 42;
  my %baz : Exported         = (a => 65, b => 66);

  sub hello : Exported(greet,uk)   { "hello there" }
  sub askme : Exportable           { "what you will" }
  sub hi    : Exportable(greet,us) { "hi there" }

  # meanwhile, in a module far, far away
  use MyExport qw(:greet);
  print hello();
  $baz{c} = 67;

=head1 DESCRIPTION

This module, when used by a package, allows that package to define
exports in a more concise way than using C<Exporter>. Instead of
having to worry what goes in C<@EXPORT>, C<@EXPORT_OK> and
C<%EXPORT_TAGS>, you can use two attributes to define exporter
behavior. This has two advantages: It frees you from the implementation
details of C<Exporter>, and it keeps the export definitions where
they belong, with the subroutines and variables.

The attributes provided by this module are:

=over 4

=item C<Exported>

Indicates that the associated subroutine or lexical variable should
be automatically exported. It will also go into the C<:all> tag
(per the rules of C<%EXPORT_TAGS>), as well as any tags you specify
as options of this attribute.

For example, the following declaration

  sub hello : Exported(greet,uk)   { ... }

will cause C<hello()> to be exported, but also be available in the
tags C<:all>, C<:greet> and C<:uk>.

=item C<Exportable>

Is like C<Exported>, except that the associated subroutine or
lexical variable won't be automatically exported.  It will still
go to the C<:all> tag in any case and all other tags specified as
attribute options.

=back

=head1 Exporting Lexical Variables

C<Exporter::Simple> allows you to export lexical variables; something
C<Exporter> can't do. What happens is that the lexical is aliased
to a global of the same name, which is then exported. So when you
manipulate that global, you're really manipulating the lexical.

The syntax for exporting lexical variables is the same as for
subroutines as lexicals can take attributes just as subroutines
do.

C<Exporter::Simple> expects some cooperation from you when exporting
lexicals. For reasons best explained by reading the (commented)
source, you need to make sure to have

  1;

as the last line of code in your module. This is the true value
you have to return from the module anyway.

=head1 Exporting Global Variables

Global variables can't take attributes as of Perl 5.6.0, so it's
necessary to export globals manually. This needs to happen during
C<BEGIN()> though, so you need to write code like this:

  BEGIN {
    export([ qw/EXPORTED_CONST @array $friend/ ], 'globals');
    exportable('EXPORTABLE_CONST', 'globals');
  }

Urgh.

However, globals will be able to take attributes in Perl 5.8.0,
and this module will then be updated to reflect those capabilities.

The two subroutines used to export globals are:

=over 4

=item C<export($symbols, $tags)>

As shown in the example above, both arguments can be either strings
(to indicate one symbol or tag) or array references to indicate
multiple symbols or tags.

The semantics are the same as for the C<Export> attribute above.

=item C<exportable($symbols, $tags)>

As C<export()>, but does not automatically export the symbols. The
semantics are the same as for the C<Exportable> attribute above.

=back

These two subroutines are automatically exported by C<Exporter::Simple>.
The reason for this brute-force export is that these subroutines
need to be used during BEGIN, but C<Exporter::Simple> doesn't have
a chance to use C<Exporter> to export those two subroutines yet.
Sigh.

=head1 TODO

=over 4

=item reflection

Retrieve information about exports

=item test using two exporting modules

To see whether C<Exporter::Simple> is ok with more than one module
using it. (I don't know why it shouldn't be, but that's what testing
is for).

=back

=head1 BUGS

If you find any bugs or oddities, please do inform the author.

=head1 AUTHOR

Marcel GrE<uuml>nauer <marcel.gruenauer@chello.at>

=head1 CONTRIBUTORS

Damian Conway <damian@conway.org>
Richard Clamp <richardc@unixbeard.net>

=head1 COPYRIGHT

Copyright 2001-2002 Marcel GrE<uuml>nauer. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1), Attribute::Handlers(3pm), Exporter(3pm).

=cut
