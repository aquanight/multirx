use v5.30;
use warnings;

use Test::More tests => 4;

use MultiRx;

my $rx = MultiRx->new(
	qr/Reges/, # line 5
	qr/malorum/, # line 6
);

open my $fd, "<t/input/sample1-60.txt" or die "Failed to open input file";

ok($rx->add_input(readline($fd)));

ok($rx->finish_input);

is($rx->start, 4);

is($rx->count, 2);