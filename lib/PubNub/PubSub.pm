package PubNub::PubSub;

use strict;
use 5.008_005;
our $VERSION = '0.07';

use Carp;
use Mojo::JSON;
use Mojo::UserAgent;

sub new {
    my $class = shift;
    my %args  = @_ % 2 ? %{$_[0]} : @_;

    $args{host} ||= 'pubsub.pubnub.com';
    $args{port} ||= 80;
    $args{timeout} ||= 60; # for ua timeout
    $args{debug} ||= $ENV{PUBNUB_DEBUG} || 0;
    $ENV{MOJO_USERAGENT_DEBUG} = $args{debug};
    $args{json} ||= Mojo::JSON->new;
    $args{publish_queue} ||= [];

    my $proto = ($args{port} == 443) ? 'https://' : 'http://';
    $args{web_host} ||= $proto . $args{host};

    return bless \%args, $class;
}

sub __ua {
    my $self = shift;

    return $self->{ua} if exists $self->{ua};

    my $ua = Mojo::UserAgent->new;
    $ua->max_redirects(3);
    $ua->inactivity_timeout($self->{timeout});
    $ua->proxy->detect; # env proxy
    $ua->cookie_jar(0);
    $ua->max_connections(1);
    $self->{ua} = $ua;

    return $ua;
}

sub publish {
    my $self = shift;

    my %params = @_ % 2 ? %{$_[0]} : @_;

    my $pub_key = $params{pub_key} || $self->{pub_key};
    $pub_key or croak "pub_key is required.";
    my $sub_key = $params{sub_key} || $self->{sub_key};
    $sub_key or croak "sub_key is required.";
    my $channel = $params{channel} || $self->{channel};
    $channel or croak "channel is required.";
    $params{messages} or croak "messages is required.";
    my $callback = $params{callback} || $self->{publish_callback};

    my $ua = $self->__ua;

    foreach my $message (@{$params{messages}}) {
        my $tx = $ua->get($self->{web_host} . qq~/publish/$pub_key/$sub_key/0/$channel/0/"$message"~, sub { $callback->($_[1]->res) if $callback });
    }
}

sub subscribe {
    my $self = shift;
    my %params = @_ % 2 ? %{$_[0]} : @_;

    my $sub_key = $params{sub_key} || $self->{sub_key};
    $sub_key or croak "sub_key is required.";
    my $channel = $params{channel} || $self->{channel};
    $channel or croak "channel is required.";

    my $callback = $params{callback} or croak "callback is required.";
    my $timetoken = $params{timetoken} || '0';

    my $ua = $self->__ua;

    my $tx = $ua->get($self->{web_host} . "/subscribe/$sub_key/$channel/0/$timetoken");
    unless ($tx->success) {
        # for example $tx->error->{message} =~ /Inactivity timeout/
        print "RECONNECTING...\n" if $self->{debug};
        return $self->subscribe(%params, timetoken => $timetoken);
    }
    my $json = $tx->res->json;

    my $rtn = $callback ? $callback->(@{ $json->[0] }) : 1;
    return unless $rtn;

    $timetoken = $json->[1];
    return $self->subscribe(%params, timetoken => $timetoken);
}

sub history {
    my $self = shift;

    if (scalar(@_) == 1 and ref($_[0]) ne 'HASH' and $_[0] =~ /^\d+$/) {
        @_ = (count => $_[0]);
        warn "->history(\$num) is deprecated and will be removed in next few releases.\n";
    }

    my %params = @_ % 2 ? %{$_[0]} : @_;

    my $sub_key = delete $params{sub_key} || $self->{sub_key};
    $sub_key or croak "sub_key is required.";
    my $channel = delete $params{channel} || $self->{channel};
    $channel or croak "channel is required.";

    my $ua = $self->__ua;

    my $tx = $ua->get($self->{web_host} . "/v2/history/sub-key/$sub_key/channel/$channel" => form => \%params);
    return [$tx->error->{message}] unless $tx->success;
    return $tx->res->json;
}

1;
__END__

=encoding utf-8

=head1 NAME

PubNub::PubSub - Perl library for rapid publishing of messages on PubNub.com

=head1 SYNOPSIS

    use PubNub::PubSub;

    my $pubnub = PubNub::PubSub->new(
        pub_key => 'demo', # only required for publish
        sub_key => 'demo',
        channel => 'sandbox',
    );

    # publish
    $pubnub->publish({
        messages => ['message1', 'message2'],
        callback => sub {
            my ($res) = @_;

            # $res is a L<Mojo::Message::Response>
            say $res->code; # 200
            say Dumper(\$res->json); # [1,"Sent","14108733777591385"]
        }
    });
    $pubnub->publish({
        channel  => 'sandbox2', # optional, if not applied, the one in ->new will be used.
        messages => ['message3', 'message4']
    });

    # subscribe
    $pubnub->subscribe({
        callback => sub {
            my (@messages) = @_;
            foreach my $msg (@messages) {
                print "# Got message: $msg\n";
            }
            return 1; # 1 to continue, 0 to stop
        }
    });


=head1 DESCRIPTION

PubNub::PubSub is Perl library for rapid publishing of messages on PubNub.com based on L<Mojo::UserAgent>

perl clone of L<https://gist.github.com/stephenlb/9496723#pubnub-http-pipelining>

For a rough test:

=over 4

=item * run perl examples/subscribe.pl in one terminal (or luanch may terminals with subscribe.pl)

=item * run perl examples/publish.pl in another terminal (you'll see all subscribe terminals will get messages.)

=back

=head1 METHOD

=head2 new

=over 4

=item * pub_key

optional, default pub_key for publish

=item * sub_key

optional, default sub_key for all methods

=item * channel

optional, default channel for all methods

=item * publish_callback

optional. default callback for publish

=item * debug

print network outgoing/incoming messages to STDERR

=back

=head2 subscribe

subscribe channel to listen for the messages.

    $pubnub->subscribe({
        callback => sub {
            my (@messages) = @_;
            foreach my $msg (@messages) {
                print "# Got message: $msg\n";
            }
            return 1; # 1 to continue, 0 to stop
        }
    });

return 0 to stop

=head2 publish

publish messages to channel

    $pubnub->publish({
        messages => ['message1', 'message2'],
        callback => sub {
            my ($res) = @_;

            # $res is a L<Mojo::Message::Response>
            say $res->code; # 200
            say Dumper(\$res->json); # [1,"Sent","14108733777591385"]
        }
    });
    $pubnub->publish({
        channel  => 'sandbox2', # optional, if not applied, the one in ->new will be used.
        messages => ['message3', 'message4']
    });

Note if you need shared callback, please pass it when do ->new with B<publish_callback>.

=head2 history

fetches historical messages of a channel

=over 4

=item * sub_key

optional, default will use the one passed to ->new

=item * channel

optional, default will use the one passed to ->new

=item * count

Specifies the number of historical messages to return. The Default is 100.

=item * reverse

Setting to true will traverse the time line in reverse starting with the newest message first. Default is false. If both start and end arguments are provided, reverse is ignored and messages are returned starting with the newest message.

=item * start

Time token delimiting the start of time slice (exclusive) to pull messages from.

=item * end

Time token delimiting the end of time slice (inclusive) to pull messages from.

=back

Sample code:

    my $history = $pubnub->history({
        count => 20,
        reverse => "false"
    });
    # $history is [["message1", "message2", ... ],"Start Time Token","End Time Token"]

for example, to fetch all the rows in history

    my $history = $pubnub->history({
        reverse => "true",
    });
    while (1) {
        print Dumper(\$history);
        last unless @{$history->[0]}; # no messages
        sleep 1;
        $history = $pubnub->history({
            reverse => "true",
            start => $history->[2]
        });
    }

=head1 AUTHOR

Binary.com E<lt>fayland@gmail.comE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2014- binary.com.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
