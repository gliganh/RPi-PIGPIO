package RPi::PIGPIO;

=head1 NAME

RPi::PIGPIO - remotely control the GPIO on a RaspberryPi using the pigpiod daemon

=head1 DESCRIPTION

This module impements a client for the pigpiod daemon, and can be used to control 
the GPIO on a local or remote RaspberryPi

=cut

use strict;
use warnings;
use XSLoader;

use Exporter 5.57 'import';

use constant {
    PI_INPUT     => 0,
    PI_OUTPUT    => 1,
    PI_ALT0      => 2,
    PI_ALT1      => 3,
    PI_ALT2      => 4,
    PI_ALT3      => 5,
    PI_ALT4      => 6,
    PI_ALT5      => 7,
    HI           => 1,
    LOW          => 0,
    RISING_EDGE  => 0,
    FALLING_EDGE => 1,
    EITHER_EDGE  => 2,
};

=head1 ERROR CODES

This is the list of error codes returned by various methods (exported constant and the equivalent value)
PI_BAD_GPIO => 
PI_BAD_MODE => 
PI_NOT_PERMITTED =>

=cut

our $VERSION     = '0.001';
our @EXPORT_OK   = qw( PI_INPUT PI_OUTPUT HI LOW RISING_EDGE FALLING_EDGE EITHER_EDGE );
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

XSLoader::load('RPi::PIGPIO', $VERSION);

=head1 METHODS

=head2 connect

Connects to the pigpiod running on the given IP address/port and returns an object
that will allow us to manipulate the GPIO on that Raspberry Pi

=cut
sub connect {
    my ($class,$address,$port) = @_;
    
    $port ||= 8888;

    my $pi = xs_connect($address,$port);

    bless \$pi, $class;
}


=head2 disconnect

Disconnect from the gpiod daemon.

The current object is no longer usable once we disconnect.

=cut
sub disconnect {
   $_[0]->xs_disconnect();
   undef $_[0];
}

=head2 get_mode

Returns the mode of a given GPIO pin

Return values :
0 => PI_INPUT
1 => PI_OUTPUT
2 => PI_ALT0
3 => PI_ALT1
4 => PI_ALT2
5 => PI_ALT3
6 => PI_ALT4
7 => PI_ALT5

=cut
sub get_mode {
   my $self = shift;
   my $pin = shift;
   
   return xs_get_mode($$self,$pin); 
}

=head2 set_mode

Sets the GPIO mode

Usage: 

    $pi->set_mode(17, PI_OUTPUT);

Valid values for $mode are exported as constants and are : PI_INPUT, PI_OUTPUT, PI_ALT0, PI_ALT1, PI_ALT2, PI_ALT3, PI_ALT4, PI_ALT5

Returns 0 if OK, otherwise PI_BAD_GPIO, PI_BAD_MODE, or PI_NOT_PERMITTED.

=cut

sub set_mode {
   my ($self,$pin,$mode) = @_;

   return xs_set_mode($$self,$pin,$mode);
}

=head2 set_level

Sets the voltage level on a GPIO pin to HI or LOW

Note: You first must set the pin mode to PI_OUTPUT 

Usage :

    $pi->set_level(17, HI);
or 
    $pi->set_level(17, LOW);

=cut
sub set_level {
   my ($self,$pin,$level) = @_;

   return xs_gpio_write($$self,$pin,$level);
}

=head2 callback

Register a method you want to be called when the level on a given pin changes

Usage :
    $pi->callback($gpio, $edge, $method_ref);

Params :
$gpio - number of the GPIO pin we want to monitor
$edge - on of RISING_EDGE, FALLING_EDGE, EITHER_EDGE
$callback_method_name - *name* the method (as string) that you want to be called when an event is detected.
The metod will be called with the gpio number, edge and tick as parameters

Usage :

    sub process_callback {
        my ($gpio, $edge, $tick) = @_;
    
        ...
    };
    
    $pi->callback(17, EITHER_EDGE, 'process_callback');

Returns the is of the callback. This ID must be used when you call C<callback_cancel>

=cut
sub callback {
    my ($self, $gpio, $edge, $callback) = @_;
    
    return xs_callback($$self,$gpio, $edge, $callback);
}

=head2 callback_cancel

Cancel a callback registered with C<callback>

Usage:
    $pi->callback_cancel(5);

Params:
$callback_id - ID of the callback you want to cancel, as returned by C<callback>

=cut
sub callback_cancel {
    my ($self,$callback_id) = @_;
    
    return xs_callback_cancel($callback_id);
}


1;