package Exporter::Simple;

use 5.008;
use warnings;
use strict;
use Attribute::Handlers;
use base 'Exporter';

our $VERSION = '1.00';

no warnings 'redefine';
sub UNIVERSAL::Exported :ATTR(CHECK,SCALAR) { export('$', @_) }
sub UNIVERSAL::Exported :ATTR(CHECK,ARRAY)  { export('@', @_) }
sub UNIVERSAL::Exported :ATTR(CHECK,HASH)   { export('%', @_) }
sub UNIVERSAL::Exported :ATTR(CHECK,CODE)   { export('',  @_)  }

sub UNIVERSAL::Exportable :ATTR(CHECK,SCALAR) { exportable('$', @_) }
sub UNIVERSAL::Exportable :ATTR(CHECK,ARRAY)  { exportable('@', @_) }
sub UNIVERSAL::Exportable :ATTR(CHECK,HASH)   { exportable('%', @_) }
sub UNIVERSAL::Exportable :ATTR(CHECK,CODE)   { exportable('',  @_)  }

sub add {
	my ($arrname, $sigil, $pkg, $symbol, $ref, $attr, $tags) = @_;
	$symbol = *{$symbol}{NAME} if ref $symbol;
	$symbol = "$sigil$symbol";
	no strict 'refs';
	push @{"$pkg\::$arrname"} => $symbol;

	$tags = [ $tags || () ] unless ref $tags eq 'ARRAY';
	push @{ ${"$pkg\::EXPORT_TAGS"}{$_}  } => $symbol for @$tags;
	push @{ ${"$pkg\::EXPORT_TAGS"}{all} } => $symbol;
}

sub export     { add(EXPORT    => @_) }
sub exportable { add(EXPORT_OK => @_) }

# Can't import right away, because when a module is use()d, import() is
# triggered during BEGIN. But subroutine names aren't defined in BEGIN,
# we only see them during CHECK (that's why the CODE handler for the
# 'Exported' attribute has to run during CHECK, whereas the variable
# handlers could run during BEGIN).

# So we make a note of what needs to be exported in an array (as
# this import() sub will be called by any module indirectly using
# Exporter::Simple), and actually trigger Exporter's import() during our
# own INIT. Fortunately this is still early enough because all the action
# in the importing module happens at run-time.

# If you need more specialized importing behaviour, do it
# yourself. Exporter::Simple is what it says - simple to use and for simple
# uses only.

sub import { push our @wants_import => \@_ }

INIT {
	local $Exporter::ExportLevel = 2;
	Exporter::import(@$_) for our @wants_import;
}

1;

__END__

=head1 NAME

Exporter::Simple - Easier set-up of module exports

=head1 SYNOPSIS

  package MyExport;
  use base 'Exporter::Simple';

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

This module, when subclassed by a package, allows that package to define
exports in a more concise way than using C<Exporter>. Instead of having to
worry what goes in C<@EXPORT>, C<@EXPORT_OK> and C<%EXPORT_TAGS>, you can
use two attributes to define exporter behavior. This has two advantages:
It frees you from the implementation details of C<Exporter>, and it
keeps the export definitions where they belong, with the subroutines
and variables.

The attributes provided by this module are:

=over 4

=item C<Exported>

Indicates that the associated subroutine or global variable should
be automatically exported. It will also go into the C<:all> tag
(per the rules of C<%EXPORT_TAGS>), as well as any tags you specify
as options of this attribute.

For example, the following declaration

  sub hello : Exported(greet,uk)   { ... }

will cause C<hello()> to be exported, but also be available in the
tags C<:all>, C<:greet> and C<:uk>.

=item C<Exportable>

Is like C<Exported>, except that the associated subroutine or
global variable won't be automatically exported.  It will still
go to the C<:all> tag in any case and all other tags specified as
attribute options.

=back

=head1 BUGS

If you find any bugs or oddities, please do inform the author.

=head1 INSTALLATION

See perlmodinstall for information and options on installing Perl modules.

=head1 AVAILABILITY

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit <http://www.perl.com/CPAN/> to find a CPAN
site near you. Or see <http://www.perl.com/CPAN/authors/id/M/MA/MARCEL/>.

=head1 VERSION

This document describes version 1.00 of C<Exporter::Simple>.

=head1 AUTHOR

Marcel GrE<uuml>nauer <marcel@cpan.org>

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
