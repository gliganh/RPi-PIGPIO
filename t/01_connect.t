#!perl

use Test::More;

use strict;
use warnings;

use RPi::PIGPIO;

my $pi = RPi::PIGPIO->connect('127.0.0.1','8888');

is(ref($pi),'RPi::PIGPIO','connected');

done_testing();
