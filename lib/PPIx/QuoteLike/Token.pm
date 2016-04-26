package PPIx::QuoteLike::Token;

use 5.008;

use strict;
use warnings;

use Carp;

our $VERSION = '0.000_001';

# Private to this package.
sub __new {
    my ( $self, %arg ) = @_;
    defined $arg{content}
	or croak 'Content required';
    return bless \%arg, ref $self || $self;
}

sub content {
    my ( $self ) = @_;
    return $self->{content};
}

sub error {
    my ( $self ) = @_;
    return $self->{error};
}

sub parent {
    my ( $self ) = @_;
    return $self->{parent};
}

sub next_sibling {
    my ( $self ) = @_;
    $self->{next_sibling}
	or return;
    return $self->{next_sibling};
}

sub previous_sibling {
    my ( $self ) = @_;
    $self->{previous_sibling}
	or return;
    return $self->{previous_sibling};
}

sub significant {
    return 1;
}

sub snext_sibling {
    my ( $sib ) = @_;
    while ( $sib = $sib->next_sibling() ) {
	$sib->significant()
	    and return $sib;
    }
    return;
}

sub sprevious_sibling {
    my ( $sib ) = @_;
    while ( $sib = $sib->previous_sibling() ) {
	$sib->significant()
	    and return $sib;
    }
    return;
}

1;

__END__

=head1 NAME

PPIx::QuoteLike::Token - Represent any token.

=head1 SYNOPSIS

This is an abstract class, and should not be instantiated by the user.

=head1 DESCRIPTION

This Perl module represents the base of the token hierarchy.

=head1 METHODS

This class supports the following public methods:

=head2 content

 say $token->content();

This method returns the text that makes up the token.

=head2 error

 say $token->error();

This method returns the error text. This will be C<undef> unless the
token actually represents an error.

=head2 parent

 my $parent = $token->parent();

This method returns the token's parent, which will be the
L<PPIx::QuoteLike|PPIx::QuoteLike> object that contains it.

=head2 next_sibling

 my $next = $token->next_sibling();

This method returns the token after the invocant, or nothing if there is
none.

=head2 previous_sibling

 my $prev = $token->previous_sibling();

This method returns the token before the invocant, or nothing if there
is none.

=head2 significant

 $token->significant()
     and say 'significant';

This Boolean method returns a true value if the token is significant,
and a false one otherwise.

=head2 snext_sibling

 my $next = $token->snext_sibling();

This method returns the significant token after the invocant, or nothing
if there is none.

=head2 sprevious_sibling

 my $prev = $token->sprevious_sibling();

This method returns the significant token before the invocant, or
nothing if there is none.

=head1 SEE ALSO

L<PPIx::QuoteLike|PPIx::QuoteLike>.

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
