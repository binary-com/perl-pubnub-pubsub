package PubNub::PubSub::Message;

use Carp;
use Mojo::JSON qw(encode_json decode_json);

use strict;
use warnings;

sub new {
    my $pkg  = shift;
    my %args = scalar @_ % 2 ? %{$_[0]} : @_;
    $args{payload} ||= $args{message}; # backwards compatibility
    croak 'Must provide payload' unless $args{payload};
    my $self = \%args;
    return bless $self, $pkg;
}

sub payload {
    my $self = shift;
    return $self->{payload};
}

sub from_msg {
    my ($self, $json) = @_;
    return "$self"->new(payload => decode_json($json));
}

sub json {
    my $self = shift;
    return encode_json($self->{payload});
}

sub query_params {
    my $self = shift;
    my $merge = shift;
    return { map {
        my $var = $self->{$_};
        $var = $merge->{$_} unless defined $var;
        defined $var ?
            ($_ => encode_json($var)) :
            ();
    } qw(ortt meta ear seqn) };
}

1;
