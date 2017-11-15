use strict;
use warnings;
use Test::More tests => 18;
use FindBin;

use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );
use Test::Rest;

# Should use the default serializer, YAML
my $t = Test::Rest->new( 'content_type' => 'text/plain' );

use_ok 'Catalyst::Test', 'Test::Catalyst::Action::REST';

foreach my $method (qw(GET DELETE POST PUT OPTIONS)) {
    my $run_method = lc($method);
    my $result     = "something $method";
    my $res;
    if ( grep /$method/, qw(GET DELETE OPTIONS) ) {
        $res = request( $t->$run_method( url => '/test' ) );
    } else {
        $res = request(
            $t->$run_method(
                url  => '/test',
                data => '',
            )
        );
    }
    ok( $res->is_success, "$method request succeeded" );
    is(
        $res->content,
        "something $method",
        "$method request had proper response"
    );
}

my $fail_res = request( $t->delete( url => '/notreally' ) );
is( $fail_res->code, 405, "Request to bad method gets 405 Not Implemented" );
is( $fail_res->header('allow'), "GET", "405 allow header properly set." );

my $options_res = request( $t->options( url => '/notreally' ) );
is( $options_res->code, 200, "OPTIONS request handler succeeded" );
is( $options_res->header('allow'),
    "GET", "OPTIONS request allow header properly set." );

my $modified_res = request( $t->get( url => '/not_modified' ) );
is( $modified_res->code, 304, "Not Modified request handler succeeded" );

my $ni_res = request( $t->delete( url => '/not_implemented' ) );
is( $ni_res->code, 200, "Custom not_implemented handler succeeded" );
is(
    $ni_res->content,
    "Not Implemented Handler",
    "not_implemented handler had proper response"
);

1;
