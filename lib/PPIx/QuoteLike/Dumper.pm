package PPIx::QuoteLike::Dumper;

use 5.006;

use strict;
use warnings;

use Carp;
use PPIx::QuoteLike;
use Scalar::Util ();

our $VERSION = '0.002';

{
    my $default = {
	encoding	=> undef,
	indent		=> 2,
	margin		=> 0,
	perl_version	=> 0,
	ppi		=> 0,
	significant	=> 0,
	tokens		=> 0,
	variables	=> 0,
    };

    sub new {
	my ( $class, $source, %arg ) = @_;

	my $self = {
	    %{ $default },
	    object	=> undef,
	    source	=> $source,
	};

	foreach my $key ( keys %{ $default } ) {
	    defined $arg{$key}
		and $self->{$key} = $arg{$key};
	}

	$self->{object} = _isa( $source, 'PPIx::QuoteLike' ) ? $source :
	    PPIx::QuoteLike->new( $source,
		map { $_ => $arg{$_} } qw{ encoding postderef },
	    )
	    or return;

	return bless $self, ref $class || $class;
    }
}

sub _isa {
    my ( $arg, $class ) = @_;
    Scalar::Util::blessed( $arg )
	or return 0;
    return $arg->isa( $class );
}

sub list {
    my ( $self, $split ) = @_;
    __PACKAGE__ eq caller	# Only this package is allowed to
	or $split = undef;	# set the $split argument.
    my $indent;
    my $obj = $self->{object};
    my @rslt;
    my $selector;
    if ( $self->{tokens} ) {
	$indent = '';
	$selector = sub { return @{
	    $obj->find( 'PPIx::QuoteLike::Token' ) || [] };
	};
    } else {
	$indent = ' ' x $self->{indent};
	my $string = sprintf '%s%s...%s',
	    map { _format_content( $obj, $_ ) }
	    qw{ type start finish };
	push @rslt,
	    join "\t", ref $obj, $string,
	    _format_attr( $obj, qw{ failures interpolates } ),
	    $self->_perl_version( $obj ),
	    $self->_variables( $obj ),
	    ;
	$selector = sub { return $obj->children() };
    }
    foreach my $elem ( $selector->() ) {
	my @line = (
	    ref $elem,
	    _quote( $elem->content() ),
	    $self->_perl_version( $elem ),
	    $self->_variables( $elem ),
	);
	my @ppi;
	@ppi = $self->_ppi( $elem, $split )
	    and push @line, shift @ppi;
	push @rslt, map { "$indent$_" } join( "\t", @line ), @ppi;
    }
    return @rslt;
}

sub print : method {	## no critic (ProhibitBuiltinHomonyms)
    my ( $self ) = @_;
    print $self->string();
    return;
}

sub string {
    my ( $self ) = @_;
    my $margin = ' ' x $self->{margin};
    return join '', map { "$margin$_\n" } $self->list( 1 );
}

sub _format_attr {
    my ( $obj, @arg ) = @_;
    my @rslt;
    foreach my $attr ( @arg ) {
	defined( my $val = $obj->$attr() )
	    or next;
	push @rslt, sprintf '%s=%s', $attr, _quote( $val );
    }
    return @rslt;
}

sub _format_content {
    my ( $obj, $method, @arg ) = @_;
    my $val = $obj->$method( @arg );
    ref $val
	and $val = $val->content();
    return defined $val ? $val : '?';
}

sub _perl_version {
    my ( $self, $elem ) = @_;
    $self->{perl_version}
	or return;
    my $intro = $elem->perl_version_introduced();
    my $remov = $elem->perl_version_removed();
    return defined $remov ? "$intro <= \$] < $remov" : "$intro <= \$]";
}

sub _ppi {
    my ( $self, $elem, $split ) = @_;

    $self->{ppi}
	and $elem->can( 'ppi' )
	or return;

    require PPI::Dumper;
    my $dumper = PPI::Dumper->new( $elem->ppi(),
	map { $_ => $self->{$_} } qw{ indent },
    );

    my $str = $dumper->string();
    chomp $str;

    $split
	and return split qr{ \n }smx, $str;

    return $str;
}

sub _quote {
    my ( $val ) = @_;
    ref $val
	and $val = $val->content();
    defined $val
	or return 'undef';
    Scalar::Util::looks_like_number( $val )
	and return $val;
    if ( $val =~ m/ \A << /smx ) {
	chomp $val;
	return "<<'__END_OF_HERE_DOCUMENT'
$val
__END_OF_HERE_DOCUMENT
";
    }

=begin comment

    $val =~ m/ [{}] /smx
	or return "q{$val}";
    $val =~ m{ / }smx
	or return "q/$val/";

=end comment

=cut

    $val =~ s/ (?= [\\'] )/\\/smxg;
    return "'$val'";
}

sub _variables {
    my ( $self, $elem ) = @_;

    $self->{variables}
	and $elem->can( 'variables' )
	or return;

    return join ',', sort $elem->variables();
}

1;

__END__

=head1 NAME

PPIx::QuoteLike::Dumper - Dump the results of parsing quotelike things

=head1 SYNOPSIS

 use PPI::QuoteLike::Dumper;
 PPIx::QuoteLike::Dumper->new( '"foo$bar baz"' )
   ->print();

=head1 DESCRIPTION

This class generates a formatted dump of a
L<PPIx::QuoteLike|PPIx::QuoteLike> object, or a string that can be made
into such an object.

=head1 METHODS

This class supports the following public methods. Methods not documented
here are private, and unsupported in the sense that the author reserves
the right to change or remove them without notice.

=head2 new

 my $dumper = PPIx::QuoteLike::Dumper->new(
     '"foo$bar baz"',
     variables	=> 1,
 );

This static method instantiates the dumper. It takes the string or
L<PPIx::QuoteLike|PPIx::QuoteLike> object to be dumped as the first
argument. Optional further arguments may be passed as name/value pairs.

The following optional arguments are recognized:

=over

=item encoding name

This argument is the encoding of the object to be dumped. It is passed
through to L<PPIx::QuoteLike|PPIx::QuoteLike>
L<new()|PPIx::QuoteLike/new> unless the first argument was a
L<PPIx::QuoteLike|PPIx::QuoteLike> object, in which case it is ignored.

=item indent number

This argument specifies the number of additional spaces to indent each
level of the parse hierarchy. This is ignored if the C<tokens> argument
is true.

The default is C<2>.

=item margin number

This argument is the number of additional spaces to indent the parse
hierarchy, over those specified by the margin.

The default is C<0>.

=item perl_version Boolean

This argument specifies whether or not the perl versions introduced and
removed are included in the dump.

The default is C<0> (i.e. false).

=item postderef Boolean

This argument specifies whether or not postfix dereferences are
recognized in interpolations. It is passed through to
L<PPIx::QuoteLike|PPIx::QuoteLike> L<new()|PPIx::QuoteLike/new> unless
the first argument was a L<PPIx::QuoteLike|PPIx::QuoteLike> object, in
which case it is ignored.

=item ppi Boolean

This argument specifies whether or not a PPI dump is provided for
interpolations.

The default is C<0> (i.e. false).

=item tokens boolean

If true, this argument causes an unstructured dump of tokens found in
the parse.

The default is C<0> (i.e. false).

=item variables Boolean

If true, this argument causes all variables actually interpolated by any
interpolations to be dumped.

The default is C<0> (i.e. false).

=back

=head2 list

 print map { "$_\n" } $dumper->list();

This method returns an array containing the dump output. one line per
element. The output has no left margin applied, and no trailing
newlines. Embedded newlines are probable if the C<ppi> argument was
specified when the dumper was instantiated.

=head2 print

 $dumper->print();

This method simply prints the result of L</string> to standard out.

=cut

sub print : method {	## no critic (ProhibitBuiltinHomonyms)
    my ( $self ) = @_;
    print $self->string();
    return;
}

=head2 string

 print $dumper->string();

This method adds left margin and newlines to the output of L</list>,
concatenates the result into a single string, and returns that string.

=cut

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
