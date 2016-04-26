use strict;
use warnings;

use 5.006;

use lib qw{ inc };

use Module::Build;
use My::Module::Build;
use My::Module::Meta;

(my $mbv = Module::Build->VERSION()) =~ s/_//g;

my $meta = My::Module::Meta->new();

my %args = (
    dist_author => 'Thomas R. Wyant, III F<wyant at cpan dot org>',
    dist_abstract => 'Parse Perl string literals and string-literal-like things.',
    module_name => 'PPIx::QuoteLike',
    build_requires => $meta->build_requires(),
    requires => $meta->requires(
	perl => $meta->requires_perl(),
    ),
    license => 'perl',
);

$mbv >= 0.28 and $args{meta_merge} = {
    no_index => {
	directory => [qw{inc t xt}],
    },
    resources => {
	bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=PPIx-QuoteLike',
    },
};

$mbv >= 0.34
    and $args{auto_configure_requires} = 0;	# Don't require Module::Build

my $bldr = My::Module::Build->new (%args);

$bldr->create_build_script ();
