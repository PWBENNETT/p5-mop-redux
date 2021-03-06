#!perl

use strict;
use warnings;

use Test::More;

BEGIN {
    eval { require Moose::Util::TypeConstraints; 1 }
        or ($ENV{RELEASE_TESTING}
            ? die
            : plan skip_all => "This test requires Moose::Util::TypeConstraints");
}

use mop;

sub type {
    if ($_[0]->isa('mop::attribute')) {
        my ($attr, $type_name) = @_;
        my $type = Moose::Util::TypeConstraints::find_type_constraint( $type_name );
        $attr->bind('before:STORE_DATA' => sub { $type->assert_valid( ${ $_[2] } ) });
    }
    elsif ($_[0]->isa('mop::method')) {
        my ($meth, @type_names) = @_;
        my @types = map { Moose::Util::TypeConstraints::find_type_constraint( $_ ) } @type_names;
        $meth->bind('before:EXECUTE' => sub {
            my @args = @{ $_[2] };
            foreach my $i ( 0 .. $#args ) {
                $types[ $i ]->assert_valid( $args[ $i ] );
            }
        });
    }
}

class Foo {
    has $!bar is rw, type('Int');

    method set_bar ($val) {
        $!bar = $val;
    }

    method add_numbers ($a, $b) is type('Int', 'Int') {
        $a + $b
    }
}

my $foo = Foo->new;
isa_ok($foo, 'Foo');
can_ok($foo, 'bar');

is($foo->bar, undef, '... the value is undef');

eval { $foo->bar(10) };
is($@, "", '... this succeeded');
is($foo->bar, 10, '... the value was set to 10');

eval { $foo->bar([]) };
like(
    $@,
    qr/^Validation failed for \'Int\' with value /,
    '... this failed correctly'
);
is($foo->bar, 10, '... the value is still 10');

eval { $foo->set_bar(100) };
is($@, "", '... this succeeded');
is($foo->bar, 100, '... the value was set to 100');

eval { $foo->set_bar([]) };
like(
    $@,
    qr/^Validation failed for \'Int\' with value /,
    '... this failed correctly'
);
is($foo->bar, 100, '... the value is still 100');

{
    my $result = eval { $foo->add_numbers(100, 100) };
    is($@, "", '... this succeeded');
    is($result, 200, '... got the result we expected too');
}

eval { $foo->add_numbers([], 20) };
like(
    $@,
    qr/^Validation failed for \'Int\' with value /,
    '... this failed correctly'
);

{
    my @traits = mop::traits::util::applied_traits(
        mop::meta('Foo')->get_attribute('$!bar')
    );

    is($traits[0]->{'trait'}, \&rw, '... the read-write trait was applied');
    is($traits[1]->{'trait'}, \&type, '... the type trait was applied');
    is_deeply($traits[1]->{'args'}, ['Int'], '... the type trait was applied with the Int arg');
}

done_testing;


