package main;

use strict;
use warnings;

use Test::More 0.88;

require_ok 'PPIx::QuoteLike::Token'
    or BAIL_OUT $@;

require_ok 'PPIx::QuoteLike::Token::Control'
    or BAIL_OUT $@;

require_ok 'PPIx::QuoteLike::Token::Delimiter'
    or BAIL_OUT $@;

require_ok 'PPIx::QuoteLike::Token::Interpolation'
    or BAIL_OUT $@;

require_ok 'PPIx::QuoteLike::Token::String'
    or BAIL_OUT $@;

require_ok 'PPIx::QuoteLike::Token::Structure'
    or BAIL_OUT $@;

require_ok 'PPIx::QuoteLike::Token::Unknown'
    or BAIL_OUT $@;

require_ok 'PPIx::QuoteLike::Token::Whitespace'
    or BAIL_OUT $@;

require_ok 'PPIx::QuoteLike'
    or BAIL_OUT $@;

my $ms = eval { PPIx::QuoteLike->new( q<''> ) };
isa_ok $ms, 'PPIx::QuoteLike'
    or BAIL_OUT $@;

done_testing;

1;
