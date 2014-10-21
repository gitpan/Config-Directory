#########################

use Test;
BEGIN { plan tests => 10 };
use Config::Directory;

#########################

# Glob testing

ok(-d "t/t8");
my $c = Config::Directory->new([ "t/t8", ], { glob => 'P*', ignore => '^PI' });
ok(ref $c);
ok(keys %$c == 3);
# Test values
ok($c->{PEACH});
ok($c->{PEAR});
ok(! exists $c->{PINEAPPLE});
ok($c->{PLUM});
ok(! exists $c->{APPLE});
ok(! exists $c->{BANANA});
ok(! exists $c->{ORANGE});
