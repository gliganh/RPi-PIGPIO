use Test::More;

use strict;
use warnings;

#test to check if all the modules compile

use Module::Find;

my @modules = findallmod RPi::PIGPIO;

foreach my $module_name (@modules) {
    
    {    
        local $@ = undef;
        eval "use $module_name";
    
        ok(! $@,"Module $module_name compiles successfuly");
        if ($@) { 
            note $@;
        }
    }
}


done_testing();