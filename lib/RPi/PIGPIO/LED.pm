package RPi::PIGPIO::LED;

=head1 NAME

RPi::PIGPIO::LED - Turn on and off a led connected to the RaspberryPi GPIO

=head1 DESCRIPTION

Uses the pigpio C library turn on and off a led connected to a local or remote RapsberryPi

What this actually does is set the GPIO to output and allow you to set the levels to HI or LOW

=cut

use strict;
use warnings;

use Carp;
use RPi::PIGPIO qw/PI_OUTPUT LOW HI/;

=head1 METHODS

=head2 new

Create a new object

Usage:

    my $led = RPi::PIGPIO::LED->new($pi,$gpio);

Arguments: 
$pi - an instance of RPi::PIGPIO
$gpio - GPIO number to which the LED is connected

=cut
sub new {
    my ($class,$pi,$gpio) = @_;
    
    if (! $gpio) {
        croak "new() expects the second argument to be the GPIO number to which the LED is connected!";
    }
    
    if (! $pi || ! ref($pi) || ref($pi) ne "RPi::PIGPIO") {
        croak "new expectes the first argument to be a RPi::PIPGIO object!";
    }
    
    my $self = {
        pi => $pi,
        gpio => $gpio,
        status => undef,
    };
    
    $self->{pi}->set_mode($self->{gpio},PI_OUTPUT);
    
    bless $self, $class;
    
    return $self;
}

=head2 on

Turn on the led

Usage :

    $led->on();

=cut
sub on {
    my $self = shift;
    
    $self->{pi}->set_level($self->{gpio},HI);
    $self->{status} = HI;
}


=head2 off

Turn off the led

Usage :

    $led->off();

=cut
sub off {
    my $self = shift;
    
    $self->{pi}->set_level($self->{gpio},LOW);
    $self->{status} = LOW;
}

1;