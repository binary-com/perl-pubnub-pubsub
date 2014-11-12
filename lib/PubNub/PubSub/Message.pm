package PubNub::PubSub::Message;

use Carp;
use JSON;

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

sub from_json {
    my ($self, $json) = @_;
    return "$self"->new(payload => JSON->new->convert_blessed->decode($json));
}

sub json {
    my $self = shift;
    return qq|"$self->{payload}"| unless ref $self->{payload};
    return JSON->new->convert_blessed->allow_nonref->encode($self->{payload});
}

sub query_params {
    my $self = shift;
    return { map {
        defined $self->{$_}                                         ?
            ($_ => JSON->new->convert_blessed->allow_nonref->encode($self->{$_})) :
            ();
    } qw(ortt meta ear seqn) };
}

1;
