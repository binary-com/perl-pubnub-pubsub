package PubNub::PubSub::Message;

use Carp;
use Encode;
use JSON::MaybeXS;

use strict;
use warnings;

## VERSION

=head1 NAME

PubNub::PubSub::Message - Message object for PubNub::PubSub

=head1 SYNOPSIS

This module is primarily used behind the scenes in PubNub::PubSub.  It is
not intended to be used directly for users.  This being said, one can use it
if you want to do your own URL management or otherwise interface with PubNub in
ways this distribution does not yet support.

 my $datastructure;
 my $message = PubNub::PubSub::Message->new(payload=> $datastructure);
 my $json = $message->json;
 my $payload = $message->payload;
 my $queryhash = $message->query_params;

=head1 METHODS

=head2 new

THis is the basic constructor.  Requires message or payload argument.  Message
is effectively an alias for payload.  Other arguments include ortt, meta, ear,
and seqn, supported per the PubNub API.  These other arguments are converted
to JSON in the query_params method below.

If a simple scalar is passed (not a reference), it is assumed that this will
be passed to PubNub as a string literal and handled appropriately.

=cut


sub new { ## no critic (RequireArgUnpacking)
    my $pkg  = shift;
    unshift @_, 'payload' if scalar @_ == 1 && !ref $_[0];
    my %args = scalar @_ % 2 ? %{$_[0]} : @_;
    $args{payload} ||= $args{message}; # backwards compatibility
    croak 'Must provide payload' unless $args{payload};
    my $self = \%args;
    return bless $self, $pkg;
}

=head2 payload

Returns the message payload

=cut

sub payload {
    my $self = shift;
    return $self->{payload};
}

=head2 from_msg($json_string)

Returns a message object with a payload from a json string.

=cut
my $json = JSON::MaybeXS->new->allow_nonref(1);
sub from_msg {
    my ($self, $json) = @_;
    my $arrayref = $json->decode(Encode::decode_utf8($json));
    return "$self"->new(payload => $arrayref->[0], timestamp => $arrayref->[1]);
}

=head2 json

Returns the payload encoded in json via Mojo::JSON

=cut

sub json {
    my $self = shift;
    return Encode::encode_utf8($json->encode($self->{payload}));
}

=head2 query_params($mergehash)

Returns a hash of query param properties (ortt, meta, ear, seqn), json-encoded,
for use in constructing URI's for PubNub requests.

=cut

sub query_params {
    my $self = shift;
    my $merge = shift;
    return { map {
        my $var = $self->{$_};
        $var = $merge->{$_} unless defined $var;
        defined $var ?
            ($_ => Encode::encode_utf8($json->encode($var))) :
            ();
    } qw(ortt meta ear seqn) };
}

1;
