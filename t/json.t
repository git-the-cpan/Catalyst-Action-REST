use strict;
use warnings;
use Test::More;
use FindBin;

use lib ("$FindBin::Bin/lib", "$FindBin::Bin/../lib");
use Test::Rest;
use utf8;

eval 'use JSON 2.12';
plan skip_all => 'Install JSON 2.12 or later to run this test' if ($@);

plan tests => 9;

use_ok 'Catalyst::Test', 'Test::Serialize';

my $json = JSON->new->utf8;
# The text/x-json should throw a warning
for ('text/x-json', 'application/json') {
    my $t = Test::Rest->new('content_type' => $_);
    my $monkey_template = {
        monkey => 'likes chicken!',
    };
    my $mres = request($t->get(url => '/monkey_get'));
    ok( $mres->is_success, 'GET the monkey succeeded' );
    is_deeply($json->decode($mres->content), $monkey_template, "GET returned the right data");

    my $post_data = {
        'sushi' => 'is good for monkey',
        'chicken' => ' 佐藤 純',
    };
    my $mres_post = request($t->post(url => '/monkey_put', data => $json->encode($post_data)));
    ok( $mres_post->is_success, "POST to the monkey succeeded");
    my $exp = "is good for monkey 佐藤 純";
    utf8::encode($exp);
    is_deeply($mres_post->content, $exp, "POST data matches");
}

1;
