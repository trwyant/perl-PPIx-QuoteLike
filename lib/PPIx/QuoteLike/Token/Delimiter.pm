package PPIx::QuoteLike::Token::Delimiter;

use 5.006;

use strict;
use warnings;

use base qw{ PPIx::QuoteLike::Token::Structure };

use PPIx::QuoteLike::Constant qw{ @CARP_NOT };

our $VERSION = '0.005';

use constant MARK_RE => eval 'qr< \p{Mark} >smx'; ## no critic (ProhibitStringyEval,RequireCheckingReturnValueOfEval)

=head2 perl_version_removed

Perl 5.29.0 made fatal the use of non-standalone graphemes as string
delimiters. Because non-characters and permanently unassigned code points
are still allowed per F<perldeprecation>, I take this to mean characters
that match C</\p{Mark}/> (i.e. combining diacritical marks).  But this
regular expression does not compile under Perl 5.6.

So:

This method returns C<'5.029'> for such delimiters B<provided> the
requisite regular expression compiles. Otherwise it return C<undef>.

=cut

sub perl_version_removed {
    my ( $self ) = @_;
    MARK_RE
	and $self->content() =~ MARK_RE
	and return '5.029';
    # I respectfully disagree with Perl Best Practices on the
    # following. When this method is called in list context is MUST
    # return undef if that's the right answer, NOT an empty list.
    return undef;	## no critic (ProhibitExplicitReturnUndef)
}

1;

__END__

=head1 NAME

PPIx::QuoteLike::Token::Delimiter - Represent a string delimiter

=head1 SYNOPSIS

This class should not be instantiated by the user. See below for public
methods.

=head1 INHERITANCE

C<PPIx::QuoteLike::Token::Delimiter> is a
L<PPIx::QuoteLike::Token|PPIx::QuoteLike::Token::Structure>.

C<PPIx::QuoteLike::Token::Delimiter> has no descendants.

=head1 DESCRIPTION

This token represents the delimiters of the string.

=head1 METHODS

This class supports no public methods in addition to those of its
superclass.

=head1 SEE ALSO

L<PPIx::QuoteLike::Token|PPIx::QuoteLike::Token>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016-2018 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
