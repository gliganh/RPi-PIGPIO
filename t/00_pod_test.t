use Test::More;

plan skip_all => "These tests are for authors only!" unless $ENV{AUTHOR_TESTING} or $ENV{RELEASE_TESTING};

eval "use Test::Pod 1.00";

plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

all_pod_files_ok( all_pod_files( qw/blib/ ) );