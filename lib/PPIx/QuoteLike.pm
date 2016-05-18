package PPIx::QuoteLike;

use 5.006;

use strict;
use warnings;

use Carp;
use Encode ();
use PPIx::QuoteLike::Constant qw{ VARIABLE_RE };
use PPIx::QuoteLike::Token::Control;
use PPIx::QuoteLike::Token::Delimiter;
use PPIx::QuoteLike::Token::Interpolation;
use PPIx::QuoteLike::Token::String;
use PPIx::QuoteLike::Token::Structure;
use PPIx::QuoteLike::Token::Unknown;
use PPIx::QuoteLike::Token::Whitespace;
use Scalar::Util ();

our $VERSION = '0.000_012';

use constant ARRAY	=> ref [];
use constant CODE	=> ref sub {};

use constant ILLEGAL_FIRST	=>
    'Tokenizer found illegal first characters';
use constant MISMATCHED_DELIM	=>
    'Tokenizer found mismatched delimiters';
use constant TRAILING_CRUFT	=>
    'Trailing characters after expression';

$PPIx::QuoteLike::DEFAULT_POSTDEREF = 1;

{
    my $match_sq = _match_enclosed( qw< ' > );
    my $match_dq = _match_enclosed( qw< " > );

    sub new {	## no critic (RequireArgUnpacking)
	my ( $class, $source, %arg ) = @_;

	my @children;

	defined $arg{postderef}
	    or $arg{postderef} = $PPIx::QuoteLike::DEFAULT_POSTDEREF;

	my $self = {
	    children	=> \@children,
	    encoding	=> $arg{encoding},
	    failures	=> 0,
	    postderef	=> ( $arg{postderef} ? 1 : 0 ),
	    source	=> $source,
	};

	bless $self, ref $class || $class;

	defined( my $string = $self->_stringify_source( $source ) )
	    or return;

	my ( $type, $gap, $content, $end_delim, $start_delim );

	$arg{trace}
	    and warn "Initial match of $string\n";

	# q<>, qq<>, qx<>
	if ( $string =~ m/ \A \s* ( q [qx]? ) ( \s* ) (?= ( \W ) ) /smxgc ) {
	    ( $type, $gap, $start_delim ) = ( $1, $2, $3 );
	    $arg{trace}
		and warn "Initial match '$type$start_delim'\n";
	    $self->{interpolates} = 'qq' eq $type ||
		'qx' eq $type && q<'> ne $start_delim;
	    my $delim_re = _match_enclosed( $start_delim );
	    $string =~ m/ \G ( $delim_re ) /smxgc
		or return $self->_link_elems(
		$self->_unknown( $string, MISMATCHED_DELIM ) );
	    ( $start_delim, $content, $end_delim ) = _chop( $1 );

	# here doc
	} elsif ( $string =~ m/ \A \s* ( << ) ( \s* )
	    ( \w+ | $match_sq | $match_dq ) \n /smxgc ) {
	    ( $type, $gap, $start_delim ) = ( $1, $2, $3 );
	    $arg{trace}
		and warn "Initial match '$type$start_delim$gap'\n";
	    $self->{interpolates} = $start_delim !~ m/ \A ' /smx;
	    if ( ref $source ) {
		my $encoding = _get_ppi_encoding( $source );
		$content = join '', map {
		    $self->__decode( $_, $encoding ) } $source->heredoc();
		$end_delim = $self->__decode(
		    $source->terminator(), $encoding );
		chomp $end_delim;
	    } else {
		$end_delim = _unquote( $start_delim );
		$string =~ m/ \G ( .*? ) ^ \Q$end_delim\E \n /smxgc
		    or return $self->_link_elems(
		    $self->_unknown( $string, MISMATCHED_DELIM ) );
		$content = $1;
	    }
	    $self->{start} = [
		PPIx::QuoteLike::Token::Delimiter->__new(
		    content	=> $start_delim,
		),
		PPIx::QuoteLike::Token::Whitespace->__new(
		    content	=> "\n",
		),
	    ];
	    $self->{finish} = [
		PPIx::QuoteLike::Token::Delimiter->__new(
		    content	=> $end_delim,
		),
		PPIx::QuoteLike::Token::Whitespace->__new(
		    content	=> "\n",
		),
	    ];

	# ``, '', "", <>
	} elsif ( $string =~ m/ \A \s* (?= ( [`'"<] ) ) /smxgc ) {
	    ( $type, $gap, $start_delim ) = ( '', '', $1 );
	    $arg{trace}
		and warn "Initial match '$type$start_delim'\n";
	    $self->{interpolates} = q<'> ne $start_delim;
	    my $delim_re = _match_enclosed( $start_delim );
	    $string =~ m/ \G ( $delim_re ) /smxgc
		or return $self->_link_elems(
		$self->_unknown( $string, MISMATCHED_DELIM ) );
	    ( $start_delim, $content, $end_delim ) = _chop( $1 );

	# Something we do not recognize
	} else {
	    $arg{trace}
		and warn "No initial match\n";
	    return $self->_link_elems( $self->_unknown(
		    $string, ILLEGAL_FIRST ) );
	}

	$self->{interpolates} = $self->{interpolates} ? 1 : 0;

	$self->{type} = [
	    PPIx::QuoteLike::Token::Structure->__new(
		content	=> $type,
	    ),
	    length $gap ? PPIx::QuoteLike::Token::Whitespace->__new(
		content	=> $gap,
	    ) : ()
	];
	$self->{start} ||= [
	    PPIx::QuoteLike::Token::Delimiter->__new(
		content	=> $start_delim,
	    ),
	];

	$arg{trace}
	    and warn "Without delimiters: '$content'\n";

	if ( $self->{interpolates} ) {
	    {	# Single-iteration loop

		if ( $content =~ m/ \G ( \\ [ULulQE] ) /smxgc ) {
		    push @children, PPIx::QuoteLike::Token::Control->__new(
			content	=> "$1",		# Remove magic
		    );
		    redo;
		}

		if ( $content =~ m/ \G ( [\$\@] \#? \$* ) /smxgc ) {
		    push @children, $self->_interpolation( "$1", $content );
		    redo;
		}

		if ( $content =~ m/ \G ( \\ . | [^\\\$\@]+ ) /smxgc ) {
		    my $content = $1;
		    @children
			and $children[-1]->isa(
			    'PPIx::QuoteLike::Token::String' )
			and $content = ( pop @children )->content() .
		    $content;
		    push @children, PPIx::QuoteLike::Token::String->__new(
			content	=> $content,
		    );
		    redo;
		}
	    }

	} else {

	    length $content
		and push @children, PPIx::QuoteLike::Token::String->__new(
		    content	=> $content,
		);

	}

	$self->{finish} ||= [
	    PPIx::QuoteLike::Token::Delimiter->__new(
		content	=> $end_delim,
	    ),
	];

	ref $_[1]
	    and pos( $_[1] ) = pos $string;

	return $self->_link_elems();
    }
}

sub child {
    my ( $self, $number ) = @_;
    return $self->{children}[$number];
}

sub children {
    my ( $self ) = @_;
    return @{ $self->{children} };
}

sub content {
    my ( $self ) = @_;
    return join '', map { $_->content() } grep { $_ } $self->elements();
}

sub delimiters {
    my ( $self ) = @_;
    return join '', grep { defined }
	map { $self->_get_value_scalar( $_ ) }
	qw{ start finish };
}

sub _get_value_scalar {
    my ( $self, $method ) = @_;
    defined( my $val = $self->$method() )
	or return;
    return ref $val ? $val->content() : $val;
}

sub elements {
    my ( $self ) = @_;
    return @{ $self->{elements} ||= [
	map { $self->$_() } qw{ type start children finish }
    ] };
}

sub encoding {
    my ( $self ) = @_;
    return $self->{encoding};
}

sub failures {
    my ( $self ) = @_;
    return $self->{failures};
}

sub find {
    my ( $self, $target ) = @_;

    my $check = CODE eq ref $target ? $target :
    ref $target ? croak 'find() target may not be ' . ref $target :
    sub { $_[0]->isa( $target ) };
    my @found;
    foreach my $elem ( $self, $self->elements() ) {
	$check->( $elem )
	    and push @found, $elem;
    }

    @found
	or return 0;

    return \@found;
}

sub finish {
    my ( $self, $inx ) = @_;
    $self->{finish}
	or return;
    wantarray
	and return @{ $self->{finish} };
    return $self->{finish}[ $inx || 0 ];
}

sub handles {
    my ( $self, $string ) = @_;
    return $self->_stringify_source( $string, test => 1 );
}

sub interpolates {
    my ( $self ) = @_;
    return $self->{interpolates};
}

sub postderef {
    my ( $self ) = @_;
    return $self->{postderef};
}

sub schild {
    my ( $self, $inx ) = @_;
    $inx ||= 0;
    my @kids = $self->schildren();
    return $kids[$inx];
}

sub schildren {
    my ( $self ) = @_;
    return (
	grep { $_->significant() } $self->children()
    );
}

sub source {
    my ( $self ) = @_;
    return $self->{source};
}

sub start {
    my ( $self, $inx ) = @_;
    $self->{start}
	or return;
    wantarray
	and return @{ $self->{start} };
    return $self->{start}[ $inx || 0 ];
}

sub type {
    my ( $self, $inx ) = @_;
    $self->{type}
	or return;
    wantarray
	and return @{ $self->{type} };
    return $self->{type}[ $inx || 0 ];
}

sub variables {
    my ( $self ) = @_;

    $self->interpolates()
	or return;

    my %var;
    foreach my $kid ( $self->children() ) {
	$kid->can( 'variables' )
	    or next;
	foreach my $sym ( $kid->variables() ) {
	    $var{$sym} = 1;
	}
    }
    return ( keys %var );
}

sub _chop {
    my ( $middle ) = @_;
    my $left = substr $middle, 0, 1, '';
    my $right = substr $middle, -1, 1, '';
    return ( $left, $middle, $right );
}

# decode data using the object's {encoding}
# It is anticipated that if I make PPIx::Regexp depend on this package,
# that this will be called there.

sub __decode {
    my ( $self, $data, $encoding ) = @_;
    $encoding ||= $self->{encoding};
    defined $encoding
	and _encode_available()
	or return $data;
    return Encode::decode( $encoding, $data );
}

{

    my $encode_available;

    sub _encode_available {
	defined $encode_available and return $encode_available;
	return ( $encode_available = eval {
		require Encode;
		1;
	    } ? 1 : 0
	);
    }

}

{
    my ( $cached_doc, $cached_encoding );

    # These are the byte order marks documented as being recognized by
    # PPI. Only utf-8 is documented as supported.
    my %known_bom = (
	'EFBBBF'	=> 'utf-8',
	'0000FEFF'	=> 'utf-32be',
	'FFFE0000'	=> 'utf-32le',
	'FEFF'		=> 'utf-16be',
	'FFFE'		=> 'utf-16le',
    );

    sub _get_ppi_encoding {
	my ( $elem ) = @_;

	my $doc = $elem->top()
	    or return;

	$cached_doc
	    and $doc == $cached_doc
	    and return $cached_encoding;

	my $bom = $doc->first_element()
	    or return;

	Scalar::Util::weaken( $cached_doc = $doc );

	if ( $bom->isa( 'PPI::Token::BOM' ) ) {
	    return ( $cached_encoding = $known_bom{
		uc unpack 'H*', $bom->content() } );
	}

	$cached_encoding = undef;

	foreach my $use (
	    @{ $doc->find( 'PPI::Statement::Include' ) || [] }
	) {
	    'use' eq $use->type()
		or next;
	    defined( my $module = $use->module() )
		or next;
	    'utf8' eq $module
		or next;
	    $cached_encoding = 'utf-8';
	    last;
	}

	return $cached_encoding;

    }

}


# This subroutine was created in an attempt to simplify control flow.
# Argument 2 (from 0) is not unpacked because the caller needs to see
# the side effects of matches made on it.

{

    my %special = (
	'$$'	=> sub {	# Process ID.
	    my ( $content ) = @_;
	    return PPIx::QuoteLike::Token::Interpolation->__new(
		content	=> $content,
	    );
	},
	'@'	=> sub {	# Called if we find '@@'.
	    my ( $content ) = @_;
	    return PPIx::QuoteLike::Token::String->__new(
		content	=> $content,
	    );
	},
    );

    sub _interpolation {	## no critic (RequireArgUnpacking)
	my ( $self, $sigil ) = @_;

	if ( $_[2] =~ m/ \G (?= \{ ) /smxgc ) {
	    my $delim_re = _match_enclosed( qw< { > );
	    $_[2] =~ m/ \G ( $delim_re ) /smxgc
		and return PPIx::QuoteLike::Token::Interpolation->__new(
		    content	=> "$sigil$1",
		);
	    $_[2] =~ m/ \G ( .* ) /smxgc
		and return $self->_unknown( "$sigil$1", MISMATCHED_DELIM );
	    confess 'Failed to match /./';
	}

	if ( $_[2] =~ m< \G ( @{[ VARIABLE_RE ]} ) >smxgco
	) {
	    my $interp = "$sigil$1";
	    while ( $_[2] =~ m/ \G  ( (?: -> )? ) (?= ( [[{] ) ) /smxgc ) {	# }]
		my $lead_in = $1;
		my $delim_re = _match_enclosed( $2 );
		if ( $_[2] =~ m/ \G ( $delim_re ) /smxgc ) {
		    $interp .= "$lead_in$1";
		} else {
		    $_[2] =~ m/ ( .* ) /smxgc;
		    return (
			PPIx::QuoteLike::Token::Interpolation->__new(
			    content	=> $interp,
			),
			$self->_unknown( "$1", MISMATCHED_DELIM ),
		    );
		}
	    }

	    # Postfix dereferencing
	    $self->postderef()
		and $_[2] =~ m/ \G ( -> (?: \$ \# | [\$\@] ) [*] ) /smxgc
		and $interp .= $1;

	    return PPIx::QuoteLike::Token::Interpolation->__new(
		content	=> $interp,
	    );
	}

	my $code = $special{$sigil}
	    or return $self->_unknown( $sigil, 'Sigil without interpolation' );

	return $code->( $sigil );

    }

}

sub _link_elems {
    my ( $self, @arg ) = @_;

    push @{ $self->{children} }, @arg;

    foreach my $key ( qw{ type start children finish } ) {
	my $prev;
	foreach my $elem ( @{ $self->{$key} } ) {
	    Scalar::Util::weaken( $elem->{parent} = $self );
	    if ( $prev ) {
		Scalar::Util::weaken( $elem->{previous_sibling} = $prev );
		Scalar::Util::weaken( $prev->{next_sibling} = $elem );
	    }
	    $prev = $elem;
	}
    }

    return $self;
}

{
    my %cache;
    my %matching_bracket = qw/ ( ) [ ] { } < > /;

    sub _match_enclosed {
	my ( $left ) = @_;
	if ( my $right = $matching_bracket{$left} ) {
	    # Based on Regexp::Common $RE{balanced}
	    return ( $cache{$left} =
		qr{ (
		    \Q$left\E
		    (?:
			(?> [^\\\Q$left$right\E]+ ) |
			(?> \\ . ) |
			(?-1)
		    )*
		    \Q$right\E
		) }smx
	    );
	} else {
	    # Based on Regexp::Common $RE{delimited}{-delim=>'`'}
	    return ( $cache{$left} ||=
		qr< (?:
		    (?: \Q$left\E )
		    (?: [^\\\Q$left\E]* (?: \\ . [^\\\Q$left\E]* )* )
		    (?: \Q$left\E )
		) >smx
	    );
	}
    }
}

sub _stringify_source {
    my ( $self, $string, %opt ) = @_;

    if ( Scalar::Util::blessed( $string ) ) {

	$string->isa( 'PPI::Element' )
	    or return;

	foreach my $class ( qw{
	    PPI::Token::Quote
	    PPI::Token::QuoteLike::Backtick
	    PPI::Token::QuoteLike::Command
	    PPI::Token::QuoteLike::Readline
	} ) {
	    $string->isa( $class )
		or next;
	    $opt{test}
		and return 1;

	    my $encoding = _get_ppi_encoding( $string );
	    return $self->__decode( $string->content(), $encoding );
	}

	if ( $string->isa( 'PPI::Token::HereDoc' ) ) {
	    $opt{test}
		and return 1;

	    my $encoding = _get_ppi_encoding( $string );
	    return $self->__decode( $string->content(), $encoding ) .  "\n";
	}

	return;

    }

    ref $string
	and return;

    $string =~ m/ \A \s* (?: q [qx]? | << | [`'"<] ) /smx
	and return $opt{test} ? 1 : $string;

    return;
}

sub _unknown {
    my ( $self, $content, $error ) = @_;
    $self->{failures}++;
    return PPIx::QuoteLike::Token::Unknown->__new(
	content	=> $content,
	error	=> $error,
    );
}

sub _unquote {
    my ( $string ) = @_;
    $string =~ s/ \A ['"] //smx
	and chop $string;
    $string =~ s/ \\ (?= . ) //smxg;
    return $string;
}

1;

__END__

=head1 NAME

PPIx::QuoteLike - Parse Perl string literals and string-literal-like things.

=head1 SYNOPSIS

 use PPIx::QuoteLike;

 my $str = PPIx::QuoteLike->new( q<"fu$bar"> );
 say $str->interpolates() ?
    'interpolates' :
    'does not interpolate';

=head1 DESCRIPTION

This Perl class parses Perl string literals and things that are
reasonably like string literals.

=head1 METHODS

This class supports the following public methods:

=head2 new

 my $str = PPIx::QuoteLike->new( $source, %arg );

This static method parses the argument, and returns a new object
containing the parse. The C<$source> argument can be either a literal or
an appropriate L<PPI::Element|PPI::Element> object.

The C<$source> argument will be parsed up to and including the trailing
delimiter if that can be determined. If the argument is a literal, its
C<pos()> will be set to the first character after the trailing literal.

C<PPI> classes that can be handled are
L<PPI::Token::Quote|PPI::Token::Quote>,
L<PPI::Token::QuoteLike::Backtick|PPI::Token::QuoteLike::Backtick>,
L<PPI::Token::QuoteLike::Command|PPI::Token::QuoteLike::Command>,
L<PPI::Token::QuoteLike::Readline|PPI::Token::QuoteLike::Readline>, and
L<PPI::Token::HereDoc|PPI::Token::HereDoc>. Any other object will cause
C<new()> to return nothing.

Scalars that can be handled are the equivalents of the above C<PPI>
classes. If a scalar argument does not look like one of the above, this
method returns nothing. The scalar representation of a here document is
a multi-line string whose first line consists of the leading C< << > and
the start delimiter, and whose subsequent lines consist of the content
of the here document and the end delimiter.

Additional, optional arguments can be passed as name/value pairs.
Supported arguments are:

=over

=item encoding

This is the encoding of the C<$source>. If this is specified as
something other than C<undef>, the C<$source> will be decoded before
processing.

If the C<$source> is a C<PPI::Element>, this encoding is used only if
the document has neither a byte order mark or C<'use utf8'>.

=item postderef

This Boolean argument determines whether postfix dereferencing is
recognized in interpolation. If unspecified, or specified as C<undef>,
it defaults to the value of C<$PPIx::QuoteLike::DEFAULT_POSTDEREF>. This
variable is not exported, and is true by default. If you change the
value, the change should be properly localized:

 local $PPIx::QuoteLike::DEFAULT_POSTDEREF = 0;

=item trace

This Boolean argument causes a trace of the parse to be written to
standard out. Setting this to a true value is unsupported in the sense
that the author makes no representation as to what will happen if you do
it, and reserves the right to make changes to the functionality, or
retract it completely, without notice.

=back

All other arguments are unsupported and reserved to the author.

=head2 child

 my $kid = $str->child( 0 );

This method returns the child element whose index is given as the
argument. Children do not include the L<type()|/type>, or the
L<start()|/start> or L<finish()|/finish> delimiters. Negative indices
are valid, and given the usual Perl interpretation.

=head2 children

 my @kids = $str->children();

This method returns all child elements. Children do not include the
L<type()|/type>, or the L<start()|/start> or L<finish()|/finish>
delimiters.

=head2 content

 say $str->content();

This method returns the content of the object. If the original argument
was a valid Perl string, this should be the same as the
originally-parsed string as far as its end delimiter.

=head2 delimiters

 say $str->delimiters();

This method returns the delimiters of the object, as a string. This will
be two characters unless the argument to L<new()|/new> was a here
document or an invalid string. In the latter case the return might be
anything.

=head2 elements

 my @elem = $str->elements();

This method returns all elements of the object. This includes
L<type()|/type>, L<start()|/start>, L<children()|/children>, and
L<finish()|/finish>, in that order.

=head2 failures

 say $str->failures();

This method returns the number of parse failures found. These are
instances where the parser could not figure out what was going on, and
should be the same as the number of
L<PPIx::QuoteLike::Token::Unknown|PPIx::QuoteLike::Token::Unknown>
objects returned by L<elements()|/elements>.

=head2 find

 for ( @{[ $str->find( $criteria ) || [] } ) {
     ...
 }

This method finds and returns a reference to an array of all elements
that meet the given criteria. If nothing is found, a false value is
returned.

The C<$criteria> can be either the name of a
L<PPIx::QuoteLike::Token|PPIx::QuoteLike::Token> class, or a code
reference. In the latter case, the code is called for each element in
L<elements()|/elements>, with the element as the only argument. The
element is included in the output if the code returns a true value.

=head2 finish

 say map { $_->content() } $str->finish();

This method returns the finishing elements of the parse. It is actually
an array, with the first element being a
L<PPIx::QuoteLike::Token::Delimiter|PPIx::QuoteLike::Token::Delimiter>.
If the parse is of a here document there will be a second element, which
will be a
L<PPIx::QuoteLike::Token::Whitespace|PPIx::QuoteLike::Token::Whitespace>
containing the trailing new line character.

If called in list context you get the whole array. If called in scalar
context you get the element whose index is given in the argument, or
element zero if no argument is specified.

=head2 handles

 say PPIx::QuoteLike->handles( $string ) ?
     "We can handle $string" :
     "We can not handle $string";

This convenience static method returns a true value if this package can
be expected to handle the content of C<$string> (be it scalar or
object), and a false value otherwise.

=head2 interpolates

 say $str->interpolates() ?
     'The string interpolates' :
     'The string does not interpolate';

This method returns a true value if the parsed string interpolates, and
a false value if it does not.

=head2 schild

 my $skid = $str->schild( 0 );

This method returns the significant child elements whose index is given
by the argument. Negative indices are interpreted in the usual way.

=head2 schildren

 my @skids = $str->schildren();

This method returns the significant children.

=head2 source

 my $source = $str->source();

This method returns the C<$source> argument to L<new()|/new>, whatever
it was.

=head2 start

 say map { $_->content() } $str->start();

This method returns the starting elements of the parse. It is actually
an array, with the first element being a
L<PPIx::QuoteLike::Token::Delimiter|PPIx::QuoteLike::Token::Delimiter>.
If the parse is of a here document there will be a second element, which
will be a
L<PPIx::QuoteLike::Token::Whitespace|PPIx::QuoteLike::Token::Whitespace>
containing the trailing new line character.

If called in list context you get the whole array. If called in scalar
context you get the element whose index is given in the argument, or
element zero if no argument is specified.

=head2 type

 my $type = $str->type();

This method returns the type object. This will be a
L<PPIx::QuoteLike::Token::Structure|PPIx::QuoteLike::Token::Structure>
if the parse was successful; otherwise it might be C<undef>. Its
contents will be everything up to the start delimiter, and will
typically be C<'q'>, C<'qq'>, C<'qx'>, C< '<<' > (for here documents),
or C<''> (for quoted strings).

The type data are actually an array. If the second element is present it
will be the white space (if any) separating the actual type from the
value.  If called in list context you get the whole array. If called in
scalar context you get the element whose index is given in the argument,
or element zero if no argument is specified.

=head2 variables

 say "Interpolates $_" for $str->variables();

This convenience method returns all interpolated variables. Each is
returned only once, and they are returned in no particular order. If the
object does not represent a string that interpolates, nothing is
returned.

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
