#########################

use Test;
BEGIN { plan tests => 9 };
use Config::Directory;

#########################

# Corner-cases (symlinks and case)

ok(-d "t/t5");
my $c = Config::Directory->new([ "t/t2", "t/t5"]);
ok(ref $c);
ok(keys %$c == 4);
# Test values
my @apple = split /\n/, $c->{APPLE};
ok(scalar(@apple) == 4 && $apple[$#apple] eq 'apple4');
# Symlink to APPLE
@apple = split /\n/, $c->{CRAB};
ok(scalar(@apple) == 4 && $apple[$#apple] eq 'apple4');
# banana vs APPLE
@apple = split /\n/, $c->{banana};
ok(scalar(@apple) == 9 && $apple[$#apple] == 9);
ok($c->{BANANA} == 2);
ok(! exists $c->{peach});
# Zero symlink overrides t2/PEAR
ok(! exists $c->{PEAR});
