package Catalyst::Action::Deserialize::View;

use Moose;
use namespace::autoclean;

extends 'Catalyst::Action';

our $VERSION = '1.16'; # VERSION

sub execute {
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
