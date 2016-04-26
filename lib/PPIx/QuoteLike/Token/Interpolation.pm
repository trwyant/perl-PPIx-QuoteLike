package PPIx::QuoteLike::Token::Interpolation;

use 5.006;

use strict;
use warnings;

use Carp;

use base qw{ PPIx::QuoteLike::Token };

our $VERSION = '0.000_001';

sub ppi {
    my ( $self ) = @_;
    ( my $content = $self->content() ) =~
	s/ \A ( [\$\@] \#? ) { ( .* ) } \z /$1$2/smx;
    require PPI::Document;
    return PPI::Document->new( \$content, readonly => 1 )
}

1;

__END__

=head1 NAME

PPIx::QuoteLike::Token::Interpolation - Represent an interpolation

=head1 SYNOPSIS

This class should not be instantiated by the user. See below for public
methods.

=head1 INHERITANCE

C<PPIx::QuoteLike::Token::Interpolation> is a
L<PPIx::QuoteLike::Token|PPIx::QuoteLike::Token>.

C<PPIx::QuoteLike::Token::Interpolation> has no descendants.

=head1 DESCRIPTION

This Perl class represents an interpolation into a quote-like string.

=head1 METHODS

This class supports the following public methods in addition to those of
its superclass:

=head2 ppi

 my $ppi = $elem->ppi();

This convenience method returns the L<PPI::Document|PPI::Document>
representing the content. This document should be considered read only.
An exception will be thrown if L<PPI::Document|PPI::Document> can not be
loaded.

Note that the content of the returned L<PPI::Document|PPI::Document> may
not be the same as the content of the original
C<PPIx::Regexp::Token::Interpolation>. This can happen because
interpolated variable names may be enclosed in curly brackets, but this
does not happen in normal code. For example, in C</${foo}bar/>, the
content of the C<PPIx::Regexp::Token::Interpolation> object will be
C<'${foo}'>, but the content of the C<PPI::Document> will be C<'$foo'>.

=head1 SEE ALSO

L<PPIx::QuoteLike::Token|PPIx::QuoteLike::Token>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
