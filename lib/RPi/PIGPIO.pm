package RPi::PIGPIO;

=head1 NAME

RPi::PIGPIO - remotely control the GPIO on a RaspberryPi using the pigpiod daemon

=head1 DESCRIPTION

This module impements a client for the pigpiod daemon, and can be used to control 
the GPIO on a local or remote RaspberryPi

On every RapberryPi that you want to use you must have pigpiod daemon running!

You can download pigpiod from here L<http://abyz.co.uk/rpi/pigpio/download.html>

=head2 SYNOPSYS

Blink a led connecyed to GPIO17 on the RasPi connected to the network with ip address 192.168.1.10

    use RPi::PIGPIO ':all';

    my $pi = RPi::PIGPIO->connect('192.168.1.10');

    $pi->set_mode(17, PI_OUTPUT);

    $pi->write(17, HI);

    sleep 3;

    $pi->write(17, LOW);

Easier mode to controll leds / switches :

    use RPi::PIGPIO;
    use RPi::PIGPIO::Device::LED;

    my $pi = RPi::PIGPIO->connect('192.168.1.10');

    my $led = RPi::PIGPIO::Device::LED->new($pi,17);

    $led->on;

    sleep 3;

    $led->off;

Same with a switch (relay):

    use RPi::PIGPIO;
    use RPi::PIGPIO::Device::Switch;

    my $pi = RPi::PIGPIO->connect('192.168.1.10');

    my $switch = RPi::PIGPIO::Device::Switch->new($pi,4);

    $switch->on;

    sleep 3;

    $switch->off;

Read the temperature and humidity from a DHT22 sensor connected to GPIO4

    use RPi::PIGPIO;
    use RPi::PIGPIO::Device::DHT22;

    my $dht22 = RPi::PIGPIO::Device::DHT22->new($pi,4);

    $dht22->trigger(); #trigger a read

    print "Temperature : ".$dht22->temperature."\n";
    print "Humidity : ".$dht22->humidity."\n";

=head1 SUPPORTED DEVICES

Note: you can write your own code using methods implemeted here to controll your own device

This is just a list of devices for which we already implemented some functionalities to make your life easier

=over 4

=item * DHT22 sensor - use L<RPi::PIGPIO::Device::DHT22>

=item * LED - use L<RPi::PIGPIO::Device::LED>

=item * generic switch / relay - use L<RPi::PIGPIO::Device::LED>

=back

=cut

use strict;
use warnings;

our $VERSION     = '0.006';

use Exporter 5.57 'import';

use IO::Socket::INET;
use Package::Constants;

use constant {
    PI_INPUT  => 0,
    PI_OUTPUT => 1,
    PI_ALT0   => 4,
    PI_ALT1   => 5,
    PI_ALT2   => 6,
    PI_ALT3   => 7,
    PI_ALT4   => 3,
    PI_ALT5   => 2,

    HI           => 1,
    LOW          => 0,

    RISING_EDGE  => 0,
    FALLING_EDGE => 1,
    EITHER_EDGE  => 2,
    
    PI_PUD_OFF  => 0,
    PI_PUD_DOWN => 1,
    PI_PUD_UP   => 2,
};

use constant {
    PI_CMD_MODES => 0,
    PI_CMD_MODEG => 1,
    PI_CMD_PUD   => 2,
    PI_CMD_READ  => 3,
    PI_CMD_WRITE => 4,
    PI_CMD_PWM   => 5,
    PI_CMD_PRS   => 6,
    PI_CMD_PFS   => 7,
    PI_CMD_SERVO => 8,
    PI_CMD_WDOG  => 9,
    PI_CMD_BR1   => 10,
    PI_CMD_BR2   => 11,
    PI_CMD_BC1   => 12,
    PI_CMD_BC2   => 13,
    PI_CMD_BS1   => 14,
    PI_CMD_BS2   => 15,
    PI_CMD_TICK  => 16,
    PI_CMD_HWVER => 17,

    PI_CMD_NO => 18,
    PI_CMD_NB => 19,
    PI_CMD_NP => 20,
    PI_CMD_NC => 21,

    PI_CMD_PRG   => 22,
    PI_CMD_PFG   => 23,
    PI_CMD_PRRG  => 24,
    PI_CMD_HELP  => 25,
    PI_CMD_PIGPV => 26,

    PI_CMD_WVCLR => 27,
    PI_CMD_WVAG  => 28,
    PI_CMD_WVAS  => 29,
    PI_CMD_WVGO  => 30,
    PI_CMD_WVGOR => 31,
    PI_CMD_WVBSY => 32,
    PI_CMD_WVHLT => 33,
    PI_CMD_WVSM  => 34,
    PI_CMD_WVSP  => 35,
    PI_CMD_WVSC  => 36,

    PI_CMD_TRIG => 37,

    PI_CMD_PROC  => 38,
    PI_CMD_PROCD => 39,
    PI_CMD_PROCR => 40,
    PI_CMD_PROCS => 41,

    PI_CMD_SLRO => 42,
    PI_CMD_SLR  => 43,
    PI_CMD_SLRC => 44,

    PI_CMD_PROCP => 45,
    PI_CMD_MICRO => 46,
    PI_CMD_MILLI => 47,
    PI_CMD_PARSE => 48,

    PI_CMD_WVCRE => 49,
    PI_CMD_WVDEL => 50,
    PI_CMD_WVTX  => 51,
    PI_CMD_WVTXR => 52,
    PI_CMD_WVNEW => 53,

    PI_CMD_I2CO  => 54,
    PI_CMD_I2CC  => 55,
    PI_CMD_I2CRD => 56,
    PI_CMD_I2CWD => 57,
    PI_CMD_I2CWQ => 58,
    PI_CMD_I2CRS => 59,
    PI_CMD_I2CWS => 60,
    PI_CMD_I2CRB => 61,
    PI_CMD_I2CWB => 62,
    PI_CMD_I2CRW => 63,
    PI_CMD_I2CWW => 64,
    PI_CMD_I2CRK => 65,
    PI_CMD_I2CWK => 66,
    PI_CMD_I2CRI => 67,
    PI_CMD_I2CWI => 68,
    PI_CMD_I2CPC => 69,
    PI_CMD_I2CPK => 70,

    PI_CMD_SPIO => 71,
    PI_CMD_SPIC => 72,
    PI_CMD_SPIR => 73,
    PI_CMD_SPIW => 74,
    PI_CMD_SPIX => 75,

    PI_CMD_SERO  => 76,
    PI_CMD_SERC  => 77,
    PI_CMD_SERRB => 78,
    PI_CMD_SERWB => 79,
    PI_CMD_SERR  => 80,
    PI_CMD_SERW  => 81,
    PI_CMD_SERDA => 82,

    PI_CMD_GDC => 83,
    PI_CMD_GPW => 84,

    PI_CMD_HC => 85,
    PI_CMD_HP => 86,

    PI_CMD_CF1 => 87,
    PI_CMD_CF2 => 88,

    PI_CMD_NOIB => 99,

    PI_CMD_BI2CC => 89,
    PI_CMD_BI2CO => 90,
    PI_CMD_BI2CZ => 91,

    PI_CMD_I2CZ => 92,

    PI_CMD_WVCHA => 93,

    PI_CMD_SLRI => 94,

    PI_CMD_CGI => 95,
    PI_CMD_CSI => 96,

    PI_CMD_FG => 97,
    PI_CMD_FN => 98,

    PI_CMD_WVTXM => 100,
    PI_CMD_WVTAT => 101,

    PI_CMD_PADS => 102,
    PI_CMD_PADG => 103,

    PI_CMD_FO    => 104,
    PI_CMD_FC    => 105,
    PI_CMD_FR    => 106,
    PI_CMD_FW    => 107,
    PI_CMD_FS    => 108,
    PI_CMD_FL    => 109,
    PI_CMD_SHELL => 110,
};


# notification flags
use constant {
    NTFY_FLAGS_ALIVE => (1 << 6),
    NTFY_FLAGS_WDOG  => (1 << 5),
    NTFY_FLAGS_GPIO  => 31,
};


our @EXPORT_OK   = Package::Constants->list( __PACKAGE__ );
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

=head1 METHODS

=head2 connect

Connects to the pigpiod running on the given IP address/port and returns an object
that will allow us to manipulate the GPIO on that Raspberry Pi

Usage:

    my $pi = RPi::PIGPIO->connect('127.0.0.1');

Params:

=over 4

=item 1. ip_address - The IP address of the pigpiod daemon

=item 2. port - optional, defaults to 8888

=back 

Note: The pigiod daemon must be running on the raspi that you want to use

=cut
sub connect {
    my ($class,$address,$port) = @_;
    
    $port ||= 8888;
    
    my $sock = IO::Socket::INET->new(
                        PeerAddr => $address,
                        PeerPort => $port,
                        Proto    => 'tcp'
                        );

    my $pi = {
        sock => $sock,
        host => $address,
        port => $port,
    };
    
    bless $pi, $class;
}


=head2 disconnect

Disconnect from the gpiod daemon.

The current object is no longer usable once we disconnect.

=cut
sub disconnect {
    my $self = shift;
    
    $self->prepare_for_exit();
    
    undef $_[0];
}

=head2 get_mode

Returns the mode of a given GPIO pin

Return values (constant exported by this module):

=over 4

=item 0 => PI_INPUT

=item 1 => PI_OUTPUT

=item 4 => PI_ALT0

=item 5 => PI_ALT1

=item 6 => PI_ALT2

=item 7 => PI_ALT3

=item 3 => PI_ALT4

=item 2 => PI_ALT5

=back

=cut
sub get_mode {
    my $self = shift;
    my $gpio = shift;
    
    die "Usage : \$pi->get_mode(<gpio>)" unless (defined($gpio));

    return $self->send_command(PI_CMD_MODEG,$gpio);
}

=head2 set_mode

Sets the GPIO mode

Usage: 

    $pi->set_mode(17, PI_OUTPUT);

Params :

=over 4

=item 1. gpio - GPIO for which you want to change the mode

=item 2. mode - the mode that you want to set. 
         Valid values for I<mode> are exported as constants and are : PI_INPUT, PI_OUTPUT, PI_ALT0, PI_ALT1, PI_ALT2, PI_ALT3, PI_ALT4, PI_ALT5

=back

Returns 0 if OK, otherwise PI_BAD_GPIO, PI_BAD_MODE, or PI_NOT_PERMITTED.

=cut

sub set_mode {
   my ($self,$gpio,$mode) = @_;
   
   die "Usage : \$pi->set_mode(<gpio>, <mode>)" unless (defined($gpio) && defined($mode));
   
   return $self->send_command(PI_CMD_MODES,$gpio,$mode);
}

=head2 write

Sets the voltage level on a GPIO pin to HI or LOW

Note: You first must set the pin mode to PI_OUTPUT 

Usage :

    $pi->write(17, HI);
or 
    $pi->write(17, LOW);

Params:

=over 4

=item 1. gpio - GPIO to witch you want to write

=item 2. level - The voltage level that you want to write (one of HI or LOW)

=back 

Note: This method will set the GPIO mode to "OUTPUT" and leave it like this

=cut
sub write {
    my ($self,$gpio,$level) = @_;
    
    return $self->send_command(PI_CMD_WRITE,$gpio,$level);
}


=head2 read

Gets the voltage level on a GPIO

Note: You first must set the pin mode to PI_INPUT

Usage :

    $pi->read(17);
or 
    $pi->read(17);


Params:

=over 4

=item 1. gpio - gpio that you want to read

=back

Note: This method will set the GPIO mode to "INPUT" and leave it like this

=cut
sub read {
    my ($self,$gpio) = @_;

    return $self->send_command(PI_CMD_READ,$gpio);
}

=head2 set_watchdog

If no level change has been detected for the GPIO for timeout milliseconds any notification 
for the GPIO has a report written to the fifo with the flags set to indicate a watchdog timeout. 

Params: 

=over 4

=item 1. gpio - GPIO for which to set the watchdog

=item 2. timeout - time to wait for a level change in milliseconds. 

=back

Only one watchdog may be registered per GPIO. 

The watchdog may be cancelled by setting timeout to 0.

NOTE: This method requires another connection to be created and subcribed to 
notifications for this GPIO (see DHT22 implementation)

=cut
sub set_watchdog {
    my ($self,$gpio,$timeout) = @_;
    
    $self->send_command( PI_CMD_WDOG, $gpio, $timeout);
}


=head2 set_pull_up_down

Set or clear the GPIO pull-up/down resistor. 

=over 4

=item 1. gpio - GPIO for which we want to modify the pull-up/down resistor

=item 2. level - PI_PUD_UP, PI_PUD_DOWN, PI_PUD_OFF.

=back

Usage:

    $pi->set_pull_up_down(18, PI_PUD_DOWN);

=cut
sub set_pull_up_down {
    my ($self,$gpio,$level) = @_;
    
    $self->send_command(PI_CMD_PUD, $gpio, $level);
}


=head2 gpio_trigger

This function sends a trigger pulse to a GPIO. The GPIO is set to level for pulseLen microseconds and then reset to not level. 

Params (in this order):

=over 4

=item 1. gpio - number of the GPIO pin we want to monitor

=item 2. length - pulse length in microseconds

=item 3. level - level to use for the trigger (HI or LOW)

=back

Usage:
    
    $pi->gpio_trigger(4,17,LOW);

Note: After running you call this method the GPIO is left in "INPUT" mode

=cut
sub gpio_trigger {
    my ($self,$gpio,$length,$level) = @_;
    
    $self->send_command_ext(PI_CMD_TRIG, $gpio, $length, [ $level ]);
}

=head1 PRIVATE METHODS

=cut

=head2 send_command

Sends a command to the pigiod daemon and waits for a response

=over 4

=item 1. command - code of the command you want to send (see package constants)

=item 2. param1 - first parameter (usualy the GPIO)

=item 3. param2 - second parameter - optional - usualy the level to which to set the GPIO (HI/LOW)

=back

=cut
sub send_command {
    my $self = shift;
    
    if (! $self->{sock}->connected) {
        $self->{sock} = IO::Socket::INET->new(
                            PeerAddr => $self->{address},
                            PeerPort => $self->{port},
                            Proto    => 'tcp'
                            );
    }
    
    return unless $self->{sock};
    
    return $self->send_command_on_socket($self->{sock},@_);
}

=head2 send_command_on_socket

Same as C<send_command> but allows you to specify the socket you want to use

The pourpose of this is to allow you to use the send_command functionality on secondary 
connections used to monitor changes on GPIO

Params:

=over 4

=item 1. socket - Instance of L<IO::Socket::INET>

=item 2. command - code of the command you want to send (see package constants)

=item 3. param1 - first parameter (usualy the GPIO)

=item 4. param2 - second parameter - optional - usualy the level to which to set the GPIO (HI/LOW)

=back

=cut
sub send_command_on_socket {
    my ($self, $sock, $cmd, $param1, $param2) = @_;
    
    $param2 //= 0;
    
    my $msg = pack('IIII', $cmd, $param1, $param2, 0);
    
    $sock->send($msg);
    
    my $response;
    
    $sock->recv($response,16);
    
    my ($x, $val) = unpack('a[12] I', $response);

    return $val;
}


=head2 send_command_ext

Sends an I<extended command> to the pigpiod daemon

=cut
sub send_command_ext {
    my ($self,$cmd,$param1,$param2,$extra_params) = @_;
    
    my $sock; 
    if (ref($self) ne "IO::Socket::INET") {
        $sock = $self->{sock};
    }
    else {
        $sock = $self;
    }
     
    my $msg = pack('IIII', $cmd, $param1, $param2, 4 * scalar(@{$extra_params // []}));
    
    $sock->send($msg);
    
    foreach (@{$extra_params // []}) {
       $sock->send(pack("I",$_));
    }
    
    my $response;
    
    $sock->recv($response,16);
    
    my ($x, $val) = unpack('a[12] I', $response);

    return $val;
}

sub prepare_for_exit {
    my $self = shift;
    
    $self->{sock}->close();
}

sub DESTROY {
    my $self = shift;
    
    $self->prepare_for_exit();
}

1;