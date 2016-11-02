package RPi::PIGPIO::Device::MH_Z14;

=head1 NAME

RPi::PIGPIO::Device::MH_Z14 - Read CO2 concentration from a MH-Z14 CO2 module

=head1 DESCRIPTION

Use the GPIO serial interface to read the CO2 concentration from a MM-Z14 module


=head1 SYNOPSIS

    use RPi::PIGPIO;
    use RPi::PIGPIO::Device::MH_Z14;

    my $pi = RPi::PIGPIO->connect('192.168.1.10');

    my $co2_sensor = RPi::PIGPIO::Device::MH-Z14->new($pi,'/dev/ttyAMA0');

    $ppm = $co2_sensor->read();

=cut

use strict;
use warnings;

use Carp;
use Time::HiRes qw/usleep/;

=head1 METHODS

=head2 new

Create a new object

Usage:

    my $led = RPi::PIGPIO::Device::MH_Z14->new($pi,mode => 'serial', tty => '/dev/ttyAMA0');

Arguments: 
$pi - an instance of RPi::PIGPIO
%params - Additional params for the sensor

Currently the params must be:

    %params = (mode => 'serial', tty => '<serial port>');

There are aditional modes in with you cand read data from this sensor (pwm and analog output),
but this modes are not implemnted yet.

=cut
sub new {
    my ($class,$pi,%params) = @_;
    
    if (! $params{mode}) {
        croak "You must specify the mode you want to use in order to read the data from the sensor";
    }
    
    
    if (! $params{tty}) {
        croak "you must specify the serial device to which the sensor is connected!";
    }
    
    if (! $pi || ! ref($pi) || ref($pi) ne "RPi::PIGPIO") {
        croak "new expectes the first argument to be a RPi::PIPGIO object!";
    }
    
    my $self = {
        pi => $pi,
        %params,
    };

    bless $self, $class;
    
    return $self;
}

=head2 read

Read the CO2 concentration (in ppm - parts per milion)

Usage :

    my $ppm = $sensor->read();

=cut
sub read {
    my $self = shift;
    
    my $pi = $self->{pi};
    
    my $h = $pi->serial_open($self->{tty},9600);

    my $request = chr(255) . chr(1) . chr(134) . chr(0) x 5 . chr((255 - 135) + 1);

    $pi->serial_write($h, $request);

    my ($count,$attempts) = (0, 100);

    while (! ($count = $pi->serial_data_available($h) && $attempts--) ) {
        usleep(1000);
    }

    my $recv = $pi->serial_read($h,$count);

    my @data = unpack("C "x9, $recv);

    my $ppm = $data[2]*256 + $data[3];
    
    $pi->serial_close($h);

    return $ppm;
}

1;