package PubNub::PubSub;

use strict;
use 5.008_005;
our $VERSION = '0.01';

use Carp;
use Mojo::IOLoop;

sub new {
    my $class = shift;
    my %args  = @_ % 2 ? %{$_[0]} : @_;

    $args{pub_key} or croak "pub_key is required.";
    $args{sub_key} or croak "sub_key is required.";
    $args{channel} or croak "channel is required.";

    $args{host} ||= 'pubsub.pubnub.com';
    $args{port} ||= 80;
    $args{timeout} ||= 60;

    return bless \%args, $class;
}

## code are copied from Hijk with changes
sub send {
    my $self = shift;
    my @msg = @_;

    my @lines;
    foreach my $msg (@msg) {
        push @lines, "GET /publish/" . $self->{pub_key} . '/' . $self->{sub_key} . '/0/' . $self->{channel} . '/0/"' . $msg . '" HTTP/1.1';
        push @lines, 'Host: pubsub.pubnub.com';
        push @lines, ''; # for \r\n
    }
    my $r = join("\r\n", @lines) . "\r\n";

    my @res;

    my $id; $id = Mojo::IOLoop->client({address => 'pubsub.pubnub.com', port => 80} => sub {
        my ($loop, $err, $stream) = @_;

        $stream->on(read => sub {
            my ($stream, $bytes) = @_;

            ## parse bytes
            push @res, $bytes;

            Mojo::IOLoop->remove($id) if scalar(@res) == scalar(@msg); # an end
        });

        # Write request
        $stream->write($r);
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

    return @res;
}

1;
__END__

=encoding utf-8

=head1 NAME

PubNub::PubSub - Blah blah blah

=head1 SYNOPSIS

  use PubNub::PubSub;

=head1 DESCRIPTION

PubNub::PubSub is

=head1 AUTHOR

Binary.com E<lt>fayland@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2014- Binary.com

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
