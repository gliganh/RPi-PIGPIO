package RPi::PIGPIO;

=head1 NAME

RPi::PIGPIO - remotely control the GPIO on a RaspberryPi using the pigpiod daemon

=head1 DESCRIPTION

This module impements a client for the pigpiod daemon, and can be used to control 
the GPIO on a local or remote RaspberryPi

=cut

use strict;
use warnings;

use Exporter 5.57 'import';
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

=head1 ERROR CODES

This is the list of error codes returned by various methods (exported constant and the equivalent value)
PI_BAD_GPIO => 
PI_BAD_MODE => 
PI_NOT_PERMITTED =>

=cut

our $VERSION     = '0.003';
our @EXPORT_OK   = Package::Constants->list( __PACKAGE__ );
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

use IO::Socket::INET;

=head1 METHODS

=head2 connect

Connects to the pigpiod running on the given IP address/port and returns an object
that will allow us to manipulate the GPIO on that Raspberry Pi

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

Return values :
    0 => PI_INPUT
    1 => PI_OUTPUT
    4 => PI_ALT0
    5 => PI_ALT1
    6 => PI_ALT2
    7 => PI_ALT3
    3 => PI_ALT4
    2 => PI_ALT5

    in/out/pwm/clock/up/down/tri

=cut
sub get_mode {
    my $self = shift;
    my $gpio = shift;

    return $self->send_command(PI_CMD_MODEG,$gpio);
}

=head2 set_mode

Sets the GPIO mode

Usage: 

    $pi->set_mode(17, PI_OUTPUT);

Valid values for $mode are exported as constants and are : PI_INPUT, PI_OUTPUT, PI_ALT0, PI_ALT1, PI_ALT2, PI_ALT3, PI_ALT4, PI_ALT5

Returns 0 if OK, otherwise PI_BAD_GPIO, PI_BAD_MODE, or PI_NOT_PERMITTED.

=cut

sub set_mode {
   my ($self,$gpio,$mode) = @_;
   
   return $self->send_command(PI_CMD_MODES,$gpio,$mode);
}

=head2 write

Sets the voltage level on a GPIO pin to HI or LOW

Note: You first must set the pin mode to PI_OUTPUT 

Usage :

    $pi->write(17, HI);
or 
    $pi->write(17, LOW);

=cut
sub write {
   my ($self,$pin,$level) = @_;

   return $self->send_command(PI_CMD_WRITE,$pin,$level);
}


=head2 read

Gets the voltage level on a GPIO

Note: You first must set the pin mode to PI_INPUT

Usage :

    $pi->read(17);
or 
    $pi->read(17);

=cut
sub read {
   my ($self,$pin) = @_;

   return $self->send_command(PI_CMD_READ,$pin);
}

=head2 callback

Register a method you want to be called when the level on a given pin changes

Usage :
    $pi->callback($gpio, $edge, $method_ref);

Params :
$gpio - number of the GPIO pin we want to monitor
$edge - on of RISING_EDGE, FALLING_EDGE, EITHER_EDGE
$callback_method - coderef to the method that you want to be called when an event is detected.
The metod will be called with the gpio number, edge and tick as parameters

Usage :

    sub process_callback {
        my ($gpio, $edge, $tick) = @_;
    
        ...
    };
    
    $pi->callback(17, EITHER_EDGE, 'process_callback');

=cut
sub callback {
    my ($self, $gpio, $edge, $callback) = @_;
    
    die "callback() if not implemeted!";
}

=head2 cancel_callback

Cancels a callback for the given GPIO

Usage:
    $pi->cancel_callback($gpio);

Params:
$gpio - gpio for which you want to cancel the callback

=cut
sub cancel_callback {
    my ($self,$gpio) = @_;
    
    delete $self->{callbacks}{$gpio};
    
    $self->{monitored_gpio} = 0;
    
    foreach my $remainig_gpio (keys %{$self->{callbacks} // {}}) {
        $self->{monitored_gpio} |= (1 << $remainig_gpio);
    }
    
    $self->send_command( PI_CMD_NB, $self->{c_handle} , $self->{monitored_gpio});
}


=head2 gpio_trigger

This function sends a trigger pulse to a GPIO. The GPIO is set to level for pulseLen microseconds and then reset to not level. 

Params (in this order):
$gpio - number of the GPIO pin we want to monitor
$length - pulse length in microseconds
$level - level to use for the trigger (HI or LOW)

Usage:
    $pi->gpio_trigger(4,17,LOW);

=cut
sub gpio_trigger {
    my ($self,$gpio,$length,$level) = @_;
    
    return xs_gpio_trigger($$self,$gpio,$length,$level);
}

=h1 PRIVATE METHODS

=cut

=h2 send_command

Sends a command to the pigiod daemon and waits for a response

=over indentlevel
=item 2. command - code of the command you want to send (see package constants)
=item 3. param1 - first parameter (usualy the GPIO)
=item 4. param2 - second parameter - optional - usualy the level to which to set the GPIO (HI/LOW)
=back

=cut
sub send_command {
    my $self = shift;
    
    return $self->send_command_on_socket($self->{sock},@_);
}

=head2 send_command_on_socket

Same as C<send_command> but allows you to specify the socket you want to use

The pourpose of this is to allow you to use the send_command functionality on secondary 
connections used to monitor changes on GPIO

Params:
=over indentlevel
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

=head2 start_callback_thread

Starts a secondary thread used to monitor user specified GPIOs for changes

=cut
sub start_callback_thread {
    my $self = shift;
    
    return if $self->{callback_thread};
    
    my $sock = IO::Socket::INET->new(
                        PeerAddr => $self->{host},
                        PeerPort => $self->{port},
                        Proto    => 'tcp'
                        );

    die "Callbacks thread failed to connect to $self->{host}:$self->{port}!" unless $sock;
}




sub prepare_for_exit {
    my $self = shift;
    
    $self->{sock}->close();
    
    if (my $callback_thread = $self->{callback_thread}) {
        my $count = 10;
        while ($callback_thread->is_running() && $count) {
            $callback_thread->kill('SIGUSR1');
            sleep 1;
            $count--;
        }
        if ($callback_thread->is_joinable()) {
            $callback_thread->join();
        }
        else {
            $callback_thread->kill('KILL');
        }
    }
}

sub DESTROY {
    my $self = shift;
    
    $self->prepare_for_exit();
}

1;