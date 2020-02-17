package main;

use 5.006;

use strict;
use warnings;

use PPI::Document;
use PPIx::QuoteLike;
use Test::More 0.88;	# Because of done_testing();

{
    note 'Parse "foo${bar}baz"';
    my $ppi = PPI::Document->new( \<<'EOD' );
#line 42 the_answer
"foo${bar}baz";
EOD
    my $qd = $ppi->find( 'PPI::Token::Quote::Double' );
    ok $qd, 'Found PPI::Token::Quote::Double';
    cmp_ok @{ $qd }, '==', 1,
	'Found exactly one PPI::Token:Quote::Double';
    my $pql = PPIx::QuoteLike->new( $qd->[0] );
    $pql->index_locations();	# For benefit of explain
    my @token = $pql->elements();
    cmp_ok scalar @token, '==', 6, 'Found 6 tokens in string';
    is_deeply $token[0]->location(), [ 2, 1, 1, 42, 'the_answer' ],
	q<Token 0 ('') location>;
    is_deeply $token[1]->location(), [ 2, 1, 1, 42, 'the_answer' ],
	q<Token 1 ('"') location>;
    is_deeply $token[2]->location(), [ 2, 2, 2, 42, 'the_answer' ],
	q<Token 2 ('foo') location>;
    is_deeply $token[3]->location(), [ 2, 5, 5, 42, 'the_answer' ],
	q<Token 3 ('${bar}') location>;
    is_deeply $token[4]->location(), [ 2, 11, 11, 42, 'the_answer' ],
	q<Token 4 ('baz') location>;
    is_deeply $token[5]->location(), [ 2, 14, 14, 42, 'the_answer' ],
	q<Token 5 ('"') location>;
    is_deeply $pql->location(), [ 2, 1, 1, 42, 'the_answer' ],
	q<String location>;

    note q<PPI document corresponding to '${bar}'>;
    my $ppi2 = $token[3]->ppi();
    @token = $ppi2->tokens();
    cmp_ok scalar @token, '==', 6, 'Interpolation PPI has 6 tokens';
    is_deeply $token[0]->location(), [ 1, 1, 1, 1, undef ],
	q<Token 0 (qq<#line 42 "the_answer"\n>) location>;
    is_deeply $token[1]->location(), [ 2, 1, 1, 42, 'the_answer' ],
	q<Token 1 ('    ') location>;
    is_deeply $token[2]->location(), [ 2, 5, 5, 42, 'the_answer' ],
	q<Token 2 ('$') location>;
    is_deeply $token[3]->location(), [ 2, 6, 6, 42, 'the_answer' ],
	q<Token 3 ('{') location>;
    is_deeply $token[4]->location(), [ 2, 7, 7, 42, 'the_answer' ],
	q<Token 4 ('bar') location>;
    is_deeply $token[5]->location(), [ 2, 10, 10, 42, 'the_answer' ],
	q<Token 5 ('}') location>;
}

done_testing;

1;

# ex: set textwidth=72 :
