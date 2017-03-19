package RPi::PIGPIO::Device::DSM501A;

=head1 NAME

RPi::PIGPIO::Device::DSM501A - Read dust particle concentraction from a DSM501A sensor

=head1 DESCRIPTION

Uses the pigpiod to read dust particle concentraction from a DSM501A sensor

The minimum recomended sampling time is 30 seconds.

Dust particles concentration is extrapolated for a cubic meter of air.

Sensor specs can be found here : https://www.elektronik.ropla.eu/pdf/stock/smy/dsm501.pdf

Acceptable room air concentration for particles ≥1 µm is 8,320,000 / cubic meter.
More info on dust levels for different environments here : https://en.wikipedia.org/wiki/Cleanroom#ISO_14644-1_and_ISO_14698

=head1 SYNOPSIS

    use RPi::PIGPIO;
    use RPi::PIGPIO::Device::DSM501A;

    my $pi = RPi::PIGPIO->connect('192.168.1.10');

    my $dust_sensor = RPi::PIGPIO::Device::DSM501A->new($pi,4);

    my $pcs = $dust_sensor->sample(30); # Sample the air for 30 seconds and report

=head1 NOTES

Please be aware that c<sample()> method will block until the sample time expires.

=cut

use strict;
use warnings;

use Carp;
use RPi::PIGPIO ':all';

use Time::HiRes qw/gettimeofday tv_interval/;

=head1 METHODS

=head2 new

Create a new object

Usage:

    my $dust_sensor = RPi::PIGPIO::Device::DSM501A->new($pi,$gpio);

Arguments: 

=over 4

=item * $pi - an instance of RPi::PIGPIO

=item * $gpio - GPIO number to which the sensor is connected

=back

=cut
sub new {
    my ($class,$pi,$gpio) = @_;
    
    if (! $gpio) {
        croak "new() expects the second argument to be the GPIO number on which the DTH22 sensor data pin is connected!";
    }
    
    if (! $pi || ! ref($pi) || ref($pi) ne "RPi::PIGPIO") {
        croak "new expectes the first argument to be a RPi::PIPGIO object!";
    }
    
    my $self = {
        pi => $pi,
        gpio => $gpio,
    };
    
    bless $self, $class;
        
    return $self;
}

=head2 sample

Sample the sensor for the given time and return the measured average concentration

Arguments: 

=over 4

=item * $sample_time - time in seconds for which to sample the device

=back

=cut
sub sample {
    my ($self, $sample_time) = @_;
    
    $sample_time ||= 30;
    
    my $sock = IO::Socket::INET->new(
                       PeerAddr => $self->{pi}{host},
                       PeerPort => $self->{pi}{port},
                       Proto    => 'tcp'
                       );

    die "Failed to open GPIO monitorring connection" unless $sock;

    my $handle = $self->{pi}->send_command_on_socket($sock, PI_CMD_NOIB, 0, 0);

    my $lastLevel = $self->{pi}->send_command(PI_CMD_BR1, 0, 0);

    #Subscribe to level changes on the DHT22 GPIO
    $self->{pi}->send_command(PI_CMD_NB, $handle , 1 << $self->{gpio});


    $self->{pi}->set_mode($self->{gpio},PI_INPUT);
    
    my $MSG_SIZE = 12;

    my $t0 = [gettimeofday];

    my @data = ();

    my $elapsed = 0;

    while ( ($elapsed = tv_interval( $t0,  [gettimeofday]) ) < $sample_time ) {

        my ($buffer,$read_buf);

        $self->{pi}->set_watchdog($self->{gpio},int( ($sample_time - $elapsed) * 1000 ));

        $sock->recv($buffer, $MSG_SIZE);
    
        while ( length($buffer) < $MSG_SIZE && $elapsed < $sample_time ) {
           $sock->recv($read_buf, $MSG_SIZE-length($buffer));
           $buffer .= $read_buf;
        }

        last unless length($buffer) == $MSG_SIZE;

        my ($seq, $flags, $tick, $level) = unpack('SSLL', $buffer);
        
        if ($flags && NTFY_FLAGS_WDOG) {
            next;
        }
        else {
            my $changed = $level ^ $lastLevel;
            $lastLevel = $level;
    
            if ( (1<<$self->{gpio}) & $changed ) {
                my $newLevel = 0;
        
                if ( (1<<$self->{gpio}) & $level ) {
                    $newLevel = 1;
                }
             
                if (EITHER_EDGE ^ $newLevel) {
                    push @data, { level => $newLevel, tick => $tick };
                }
            }

        }

    }

    $elapsed = tv_interval( $t0,  [gettimeofday]);

    # Calculate total time the device was in "LOW" state
    my $sum = 0;

    foreach (1..$#data) {
        # On rasing edge - calculate time spent on LOW
        if ($data[$_]{level} == 1) {
            $sum += $data[$_]{tick} - $data[$_-1]{tick};
        }
    }

    # percentage of total time spent in LOW level
    my $ratio = (($sum / 1_000_000) *100) / $elapsed;

    # convert ratio to actual value 100% in LOW state over 30 sec means 15000 pcs / 283.1685 ml of air
    my $max_pcs = 15_000 * ( $sample_time / 30 );
    
    my $actual_pcs_per_cubic_meter = ( $max_pcs * $ratio / 100 ) * (1/0.02831685);
    
    return $actual_pcs_per_cubic_meter;
}

1;