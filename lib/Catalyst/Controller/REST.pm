package Catalyst::Controller::REST;
$Catalyst::Controller::REST::VERSION = '1.18';
use Moose;
use namespace::autoclean;

=head1 NAME

Catalyst::Controller::REST - A RESTful controller

=head1 SYNOPSIS

    package Foo::Controller::Bar;
    use Moose;
    use namespace::autoclean;

    BEGIN { extends 'Catalyst::Controller::REST' }

    sub thing : Local : ActionClass('REST') { }

    # Answer GET requests to "thing"
    sub thing_GET {
       my ( $self, $c ) = @_;

       # Return a 200 OK, with the data in entity
       # serialized in the body
       $self->status_ok(
            $c,
            entity => {
                some => 'data',
                foo  => 'is real bar-y',
            },
       );
    }

    # Answer PUT requests to "thing"
    sub thing_PUT {
        my ( $self, $c ) = @_;

        $radiohead = $c->req->data->{radiohead};

        $self->status_created(
            $c,
            location => $c->req->uri,
            entity => {
                radiohead => $radiohead,
            }
        );
    }

=head1 DESCRIPTION

Catalyst::Controller::REST implements a mechanism for building
RESTful services in Catalyst.  It does this by extending the
normal Catalyst dispatch mechanism to allow for different
subroutines to be called based on the HTTP Method requested,
while also transparently handling all the serialization/deserialization for
you.

This is probably best served by an example.  In the above
controller, we have declared a Local Catalyst action on
"sub thing", and have used the ActionClass('REST').

Below, we have declared "thing_GET" and "thing_PUT".  Any
GET requests to thing will be dispatched to "thing_GET",
while any PUT requests will be dispatched to "thing_PUT".

Any unimplemented HTTP methods will be met with a "405 Method Not Allowed"
response, automatically containing the proper list of available methods.  You
can override this behavior through implementing a custom
C<thing_not_implemented> method.

If you do not provide an OPTIONS handler, we will respond to any OPTIONS
requests with a "200 OK", populating the Allowed header automatically.

Any data included in C<< $c->stash->{'rest'} >> will be serialized for you.
The serialization format will be selected based on the content-type
of the incoming request.  It is probably easier to use the L<STATUS HELPERS>,
which are described below.

"The HTTP POST, PUT, and OPTIONS methods will all automatically
L<deserialize|Catalyst::Action::Deserialize> the contents of
C<< $c->request->body >> into the C<< $c->request->data >> hashref", based on
the request's C<Content-type> header. A list of understood serialization
formats is L<below|/AVAILABLE SERIALIZERS>.

If we do not have (or cannot run) a serializer for a given content-type, a 415
"Unsupported Media Type" error is generated.

To make your Controller RESTful, simply have it

  BEGIN { extends 'Catalyst::Controller::REST' }

=head1 CONFIGURATION

See L<Catalyst::Action::Serialize/CONFIGURATION>. Note that the C<serialize>
key has been deprecated.

=head1 SERIALIZATION

Catalyst::Controller::REST will automatically serialize your
responses, and deserialize any POST, PUT or OPTIONS requests. It evaluates
which serializer to use by mapping a content-type to a Serialization module.
We select the content-type based on:

=over

=item B<The Content-Type Header>

If the incoming HTTP Request had a Content-Type header set, we will use it.

=item B<The content-type Query Parameter>

If this is a GET request, you can supply a content-type query parameter.

=item B<Evaluating the Accept Header>

Finally, if the client provided an Accept header, we will evaluate
it and use the best-ranked choice.

=back

=head1 AVAILABLE SERIALIZERS

A given serialization mechanism is only available if you have the underlying
modules installed.  For example, you can't use XML::Simple if it's not already
installed.

In addition, each serializer has its quirks in terms of what sorts of data
structures it will properly handle.  L<Catalyst::Controller::REST> makes
no attempt to save you from yourself in this regard. :)

=over 2

=item * C<text/x-yaml> => C<YAML::Syck>

Returns YAML generated by L<YAML::Syck>.

=item * C<text/html> => C<YAML::HTML>

This uses L<YAML::Syck> and L<URI::Find> to generate YAML with all URLs turned
to hyperlinks.  Only usable for Serialization.

=item * C<application/json> => C<JSON>

Uses L<JSON> to generate JSON output.  It is strongly advised to also have
L<JSON::XS> installed.  The C<text/x-json> content type is supported but is
deprecated and you will receive warnings in your log.

You can also add a hash in your controller config to pass options to the json object.
For instance, to relax permissions when deserializing input, add:
  __PACKAGE__->config(
    json_options => { relaxed => 1 }
  )

=item * C<text/javascript> => C<JSONP>

If a callback=? parameter is passed, this returns javascript in the form of: $callback($serializedJSON);

Note - this is disabled by default as it can be a security risk if you are unaware.

The usual MIME types for this serialization format are: 'text/javascript', 'application/x-javascript',
'application/javascript'.

=item * C<text/x-data-dumper> => C<Data::Serializer>

Uses the L<Data::Serializer> module to generate L<Data::Dumper> output.

=item * C<text/x-data-denter> => C<Data::Serializer>

Uses the L<Data::Serializer> module to generate L<Data::Denter> output.

=item * C<text/x-data-taxi> => C<Data::Serializer>

Uses the L<Data::Serializer> module to generate L<Data::Taxi> output.

=item * C<text/x-config-general> => C<Data::Serializer>

Uses the L<Data::Serializer> module to generate L<Config::General> output.

=item * C<text/x-php-serialization> => C<Data::Serializer>

Uses the L<Data::Serializer> module to generate L<PHP::Serialization> output.

=item * C<text/xml> => C<XML::Simple>

Uses L<XML::Simple> to generate XML output.  This is probably not suitable
for any real heavy XML work. Due to L<XML::Simple>s requirement that the data
you serialize be a HASHREF, we transform outgoing data to be in the form of:

  { data => $yourdata }

=item * L<View>

Uses a regular Catalyst view.  For example, if you wanted to have your
C<text/html> and C<text/xml> views rendered by TT, set:

  __PACKAGE__->config(
      map => {
          'text/html' => [ 'View', 'TT' ],
          'text/xml'  => [ 'View', 'XML' ],
      }
  );

Your views should have a C<process> method like this:

  sub process {
      my ( $self, $c, $stash_key ) = @_;

      my $output;
      eval {
          $output = $self->serialize( $c->stash->{$stash_key} );
      };
      return $@ if $@;

      $c->response->body( $output );
      return 1;  # important
  }

  sub serialize {
      my ( $self, $data ) = @_;

      my $serialized = ... process $data here ...

      return $serialized;
  }

=item * Callback

For infinite flexibility, you can provide a callback for the
deserialization/serialization steps.

  __PACKAGE__->config(
      map => {
          'text/xml'  => [ 'Callback', { deserialize => \&parse_xml, serialize => \&render_xml } ],
      }
  );

The C<deserialize> callback is passed a string that is the body of the
request and is expected to return a scalar value that results from
the deserialization.  The C<serialize> callback is passed the data
structure that needs to be serialized and must return a string suitable
for returning in the HTTP response.  In addition to receiving the scalar
to act on, both callbacks are passed the controller object and the context
(i.e. C<$c>) as the second and third arguments.

=back

By default, L<Catalyst::Controller::REST> will return a
C<415 Unsupported Media Type> response if an attempt to use an unsupported
content-type is made.  You can ensure that something is always returned by
setting the C<default> config option:

  __PACKAGE__->config(default => 'text/x-yaml');

would make it always fall back to the serializer plugin defined for
C<text/x-yaml>.

=head1 CUSTOM SERIALIZERS

Implementing new Serialization formats is easy!  Contributions
are most welcome!  If you would like to implement a custom serializer,
you should create two new modules in the L<Catalyst::Action::Serialize>
and L<Catalyst::Action::Deserialize> namespace.  Then assign your new
class to the content-type's you want, and you're done.

See L<Catalyst::Action::Serialize> and L<Catalyst::Action::Deserialize>
for more information.

=head1 STATUS HELPERS

Since so much of REST is in using HTTP, we provide these Status Helpers.
Using them will ensure that you are responding with the proper codes,
headers, and entities.

These helpers try and conform to the HTTP 1.1 Specification.  You can
refer to it at: L<http://www.w3.org/Protocols/rfc2616/rfc2616.txt>.
These routines are all implemented as regular subroutines, and as
such require you pass the current context ($c) as the first argument.

=over

=cut

BEGIN { extends 'Catalyst::Controller' }
use Params::Validate qw(SCALAR OBJECT);

__PACKAGE__->mk_accessors(qw(serialize));

__PACKAGE__->config(
    'stash_key' => 'rest',
    'map'       => {
        'text/xml'           => 'XML::Simple',
        'application/json'   => 'JSON',
        'text/x-json'        => 'JSON',
    },
);

sub begin : ActionClass('Deserialize') { }

sub end : ActionClass('Serialize') { }

=item status_ok

Returns a "200 OK" response.  Takes an "entity" to serialize.

Example:

  $self->status_ok(
    $c,
    entity => {
        radiohead => "Is a good band!",
    }
  );

=cut

sub status_ok {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { entity => 1, }, );

    $c->response->status(200);
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_created

Returns a "201 CREATED" response.  Takes an "entity" to serialize,
and a "location" where the created object can be found.

Example:

  $self->status_created(
    $c,
    location => $c->req->uri,
    entity => {
        radiohead => "Is a good band!",
    }
  );

In the above example, we use the requested URI as our location.
This is probably what you want for most PUT requests.

=cut

sub status_created {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate(
        @_,
        {
            location => { type     => SCALAR | OBJECT },
            entity   => { optional => 1 },
        },
    );

    $c->response->status(201);
    $c->response->header( 'Location' => $p{location} );
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_accepted

Returns a "202 ACCEPTED" response.  Takes an "entity" to serialize.
Also takes optional "location" for queue type scenarios.

Example:

  $self->status_accepted(
    $c,
    location => $c->req->uri,
    entity => {
        status => "queued",
    }
  );

=cut

sub status_accepted {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate(
        @_,
        {
            location => { type => SCALAR | OBJECT, optional => 1 },
            entity   => 1,
        },
    );

    $c->response->status(202);
    $c->response->header( 'Location' => $p{location} ) if exists $p{location};
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_no_content

Returns a "204 NO CONTENT" response.

=cut

sub status_no_content {
    my $self = shift;
    my $c    = shift;
    $c->response->status(204);
    $self->_set_entity( $c, undef );
    return 1;
}

=item status_multiple_choices

Returns a "300 MULTIPLE CHOICES" response. Takes an "entity" to serialize, which should
provide list of possible locations. Also takes optional "location" for preferred choice.

=cut

sub status_multiple_choices {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate(
        @_,
        {
            entity => 1,
            location => { type     => SCALAR | OBJECT, optional => 1 },
        },
    );

    $c->response->status(300);
    $c->response->header( 'Location' => $p{location} ) if exists $p{'location'};
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_found

Returns a "302 FOUND" response. Takes an "entity" to serialize.
Also takes optional "location".

=cut

sub status_found {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate(
        @_,
        {
            entity => 1,
            location => { type     => SCALAR | OBJECT, optional => 1 },
        },
    );

    $c->response->status(302);
    $c->response->header( 'Location' => $p{location} ) if exists $p{'location'};
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_bad_request

Returns a "400 BAD REQUEST" response.  Takes a "message" argument
as a scalar, which will become the value of "error" in the serialized
response.

Example:

  $self->status_bad_request(
    $c,
    message => "Cannot do what you have asked!",
  );

=cut

sub status_bad_request {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { message => { type => SCALAR }, }, );

    $c->response->status(400);
    $c->log->debug( "Status Bad Request: " . $p{'message'} ) if $c->debug;
    $self->_set_entity( $c, { error => $p{'message'} } );
    return 1;
}

=item status_forbidden

Returns a "403 FORBIDDEN" response.  Takes a "message" argument
as a scalar, which will become the value of "error" in the serialized
response.

Example:

  $self->status_forbidden(
    $c,
    message => "access denied",
  );

=cut

sub status_forbidden {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { message => { type => SCALAR }, }, );

    $c->response->status(403);
    $c->log->debug( "Status Forbidden: " . $p{'message'} ) if $c->debug;
    $self->_set_entity( $c, { error => $p{'message'} } );
    return 1;
}

=item status_not_found

Returns a "404 NOT FOUND" response.  Takes a "message" argument
as a scalar, which will become the value of "error" in the serialized
response.

Example:

  $self->status_not_found(
    $c,
    message => "Cannot find what you were looking for!",
  );

=cut

sub status_not_found {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { message => { type => SCALAR }, }, );

    $c->response->status(404);
    $c->log->debug( "Status Not Found: " . $p{'message'} ) if $c->debug;
    $self->_set_entity( $c, { error => $p{'message'} } );
    return 1;
}

=item gone

Returns a "41O GONE" response.  Takes a "message" argument as a scalar,
which will become the value of "error" in the serialized response.

Example:

  $self->status_gone(
    $c,
    message => "The document have been deleted by foo",
  );

=cut

sub status_gone {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { message => { type => SCALAR }, }, );

    $c->response->status(410);
    $c->log->debug( "Status Gone " . $p{'message'} ) if $c->debug;
    $self->_set_entity( $c, { error => $p{'message'} } );
    return 1;
}

=item status_see_other

Returns a "303 See Other" response.  Takes an optional "entity" to serialize,
and a "location" where the client should redirect to.

Example:

  $self->status_see_other(
    $c,
    location => $some_other_url,
    entity => {
        radiohead => "Is a good band!",
    }
  );

=cut

sub status_see_other {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate(
        @_,
        {
            location => { type     => SCALAR | OBJECT },
            entity   => { optional => 1 },
        },
    );

    $c->response->status(303);
    $c->response->header( 'Location' => $p{location} );
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_moved

Returns a "301 MOVED" response.  Takes an "entity" to serialize, and a
"location" where the created object can be found.

Example:

 $self->status_moved(
   $c,
   location => '/somewhere/else',
   entity => {
     radiohead => "Is a good band!",
   },
 );

=cut

sub status_moved {
   my $self = shift;
   my $c    = shift;
   my %p    = Params::Validate::validate(
      @_,
      {
         location => { type     => SCALAR | OBJECT },
         entity   => { optional => 1 },
      },
   );

   my $location = ref $p{location}
      ? $p{location}->as_string
      : $p{location}
   ;

   $c->response->status(301);
   $c->response->header( Location => $location );
   $self->_set_entity($c, $p{entity});
   return 1;
}

sub _set_entity {
    my $self   = shift;
    my $c      = shift;
    my $entity = shift;
    if ( defined($entity) ) {
        $c->stash->{ $self->{'stash_key'} } = $entity;
    }
    return 1;
}

=back

=head1 MANUAL RESPONSES

If you want to construct your responses yourself, all you need to
do is put the object you want serialized in $c->stash->{'rest'}.

=head1 IMPLEMENTATION DETAILS

This Controller ties together L<Catalyst::Action::REST>,
L<Catalyst::Action::Serialize> and L<Catalyst::Action::Deserialize>.  It should be suitable for most applications.  You should be aware that it:

=over 4

=item Configures the Serialization Actions

This class provides a default configuration for Serialization.  It is currently:

  __PACKAGE__->config(
      'stash_key' => 'rest',
      'map'       => {
         'text/html'          => 'YAML::HTML',
         'text/xml'           => 'XML::Simple',
         'text/x-yaml'        => 'YAML',
         'application/json'   => 'JSON',
         'text/x-json'        => 'JSON',
         'text/x-data-dumper' => [ 'Data::Serializer', 'Data::Dumper' ],
         'text/x-data-denter' => [ 'Data::Serializer', 'Data::Denter' ],
         'text/x-data-taxi'   => [ 'Data::Serializer', 'Data::Taxi'   ],
         'application/x-storable'   => [ 'Data::Serializer', 'Storable' ],
         'application/x-freezethaw' => [ 'Data::Serializer', 'FreezeThaw' ],
         'text/x-config-general'    => [ 'Data::Serializer', 'Config::General' ],
         'text/x-php-serialization' => [ 'Data::Serializer', 'PHP::Serialization' ],
      },
  );

You can read the full set of options for this configuration block in
L<Catalyst::Action::Serialize>.

=item Sets a C<begin> and C<end> method for you

The C<begin> method uses L<Catalyst::Action::Deserialize>.  The C<end>
method uses L<Catalyst::Action::Serialize>.  If you want to override
either behavior, simply implement your own C<begin> and C<end> actions
and forward to another action with the Serialize and/or Deserialize
action classes:

  package Foo::Controller::Monkey;
  use Moose;
  use namespace::autoclean;

  BEGIN { extends 'Catalyst::Controller::REST' }

  sub begin : Private {
    my ($self, $c) = @_;
    ... do things before Deserializing ...
    $c->forward('deserialize');
    ... do things after Deserializing ...
  }

  sub deserialize : ActionClass('Deserialize') {}

  sub end :Private {
    my ($self, $c) = @_;
    ... do things before Serializing ...
    $c->forward('serialize');
    ... do things after Serializing ...
  }

  sub serialize : ActionClass('Serialize') {}

If you need to deserialize multipart requests (i.e. REST data in
one part and file uploads in others) you can do so by using the
L<Catalyst::Action::DeserializeMultiPart> action class.

=back

=head1 A MILD WARNING

I have code in production using L<Catalyst::Controller::REST>.  That said,
it is still under development, and it's possible that things may change
between releases.  I promise to not break things unnecessarily. :)

=head1 SEE ALSO

L<Catalyst::Action::REST>, L<Catalyst::Action::Serialize>,
L<Catalyst::Action::Deserialize>

For help with REST in general:

The HTTP 1.1 Spec is required reading. http://www.w3.org/Protocols/rfc2616/rfc2616.txt

Wikipedia! http://en.wikipedia.org/wiki/Representational_State_Transfer

The REST Wiki: http://rest.blueoxen.net/cgi-bin/wiki.pl?FrontPage

=head1 AUTHORS

See L<Catalyst::Action::REST> for authors.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
