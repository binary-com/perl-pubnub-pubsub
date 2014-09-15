package PubNub::PubSub;

use strict;
use 5.008_005;
our $VERSION = '0.05';

use Carp;
use Mojo::IOLoop;
use Socket qw/$CRLF/;
use Mojo::JSON;
use Mojo::UserAgent;
use Scalar::Util qw(weaken);

sub new {
    my $class = shift;
    my %args  = @_ % 2 ? %{$_[0]} : @_;

    $args{host} ||= 'pubsub.pubnub.com';
    $args{port} ||= 80;
    $args{timeout} ||= 60; # for ua timeout
    $args{publish_timeout} ||= 3600;
    $args{subscribe_timeout} ||= 3600; # subcribe streaming timeout, default to 1 hours
    $args{debug} ||= $ENV{PUBNUB_DEBUG} || 0;
    $args{json} ||= Mojo::JSON->new;
    $args{publish_queue} ||= [];

    my $proto = ($args{port} == 443) ? 'https://' : 'http://';
    $args{web_host} ||= $proto . $args{host};

    return bless \%args, $class;
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

    my @messages = @{ $params{messages} };
    foreach my $message (@messages) {
        push @{ $self->{publish_queue} }, {
            pub_key => $pub_key, sub_key => $sub_key, channel => $channel,
            message => $message
        };
    }

    weaken $self;
    $self->__build_stream('__publish_stream', sub {
        my ($stream, $bytes) = @_;

        print STDERR "<<<<<<\n$bytes\n<<<<<<\n" if $self->{debug};

        my $callback = $self->{publish_callback};
        if ($callback) {
            my @parts = split(/(HTTP\/1\.1 )/, $self->{__publish_buf} . $bytes);
            shift @parts if $parts[0] eq '';

            $self->{__publish_buf} = '';
            while (@parts >= 2) {
                my $one_resp = join('', shift @parts, shift @parts);
                my %data = $self->parse_response($one_resp);
                if ($data{error}) {
                    $self->{__publish_buf} = $one_resp;
                    $self->{__publish_buf} .= join('', @parts) if @parts;
                    last;
                } else {
                    $callback->(\%data);
                }
            }
        }

        # Write request
        $self->__write_publish();
    }, $self->{publish_timeout});

    # Write request
    $self->__write_publish();

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub __write_publish {
    my ($self) = @_;

    my $queue = $self->{publish_queue};
    unless (scalar(@$queue)) {
        Mojo::IOLoop->stop;
        return;
    }

    my $q = shift @$queue;
    my ($pub_key, $sub_key, $channel, $message) = ($q->{pub_key}, $q->{sub_key}, $q->{channel}, $q->{message});

    my $r = join("\r\n",
        qq~GET /publish/$pub_key/$sub_key/0/$channel/0/"$message" HTTP/1.1~,
        'Host: pubsub.pubnub.com',
        ''
    ) . "\r\n";
    print STDERR ">>>>>>\n" . $r . "\n>>>>>>\n" if $self->{debug};
    my $stream = $self->{'__publish_stream'};
    $stream->write($r);
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

    weaken $self;
    my $stream = $self->__build_stream('__subscribe_stream', sub {
        my ($stream, $bytes) = @_;

        my %data = $self->parse_response($self->{__subscribe_buf} . $bytes);
        print STDERR "<<<<<<\n$bytes\n<<<<<<\n" if $self->{debug};

        if ($data{code} == 403) {
            print STDERR "403 Forbidden: " . $data{body} . "\n";
            return;
        }

        ## incomplete data
        if ($data{error}) {
            if ($data{message} eq 'incomplete') { # wait a bit more for completed data
                $self->{__subscribe_buf} .= $bytes;
                return;
            }

            # should never happen
            $self->{__subscribe_buf} = '';
            my $r = $self->__build_subscribe_req($sub_key, $channel, $timetoken);
            print STDERR ">>>>>>\n" . $r . "\n>>>>>>\n" if $self->{debug};
            return $stream->write($r); # retry with old token
        }
        $self->{__subscribe_buf} = '';

        if ($data{json}) {
            $timetoken = $data{json}->[1];
        } else {
            # should never happen
            # die Dumper(\%data); use Data::Dumper;
        }

        ## parse bytes
        my $rtn = $callback ? $callback->(@{ $data{json}->[0] }) : 1;
        unless ($rtn) {
            return Mojo::IOLoop->stop; # stop it
        }

        # Write request
        my $r = $self->__build_subscribe_req($sub_key, $channel, $timetoken);
        print STDERR ">>>>>>\n" . $r . "\n>>>>>>\n" if $self->{debug};
        $stream->write($r); # retry with old token
    }, $self->{subscribe_timeout});

    # Write request
    my $r = $self->__build_subscribe_req($sub_key, $channel, $timetoken);
    print STDERR ">>>>>>\n" . $r . "\n>>>>>>\n" if $self->{debug};
    $stream->write($r); # retry with old token

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub __build_subscribe_req {
    my ($self, $sub_key, $channel, $timetoken) = @_;

    return join("\r\n",
        "GET /subscribe/$sub_key/$channel/0/$timetoken HTTP/1.1",
        'Host: pubsub.pubnub.com',
        ''
    ) . "\r\n";
}

sub __build_stream {
    my ($self, $k, $callback, $timeout) = @_;

    return $self->{$k} if $self->{$k}; # already built

    print "Connecting stream for $k ...\n" if $self->{debug};
    weaken $self;

    my $delay = Mojo::IOLoop->delay;
    my $end   = $delay->begin;
    my $handle = undef;
    my $client_id = Mojo::IOLoop->client({
        address => $self->{host},
        port => $self->{port},
        timeout => $timeout
    } => sub {
        my ($loop, $err, $stream) = @_;
        $handle = $stream->steal_handle;
        $end->();
    });
    $delay->wait;

    my $stream = Mojo::IOLoop::Stream->new($handle)->timeout($timeout);
    Mojo::IOLoop->stream($stream);

    $stream->on(read => sub { $callback->(@_); });
    $self->{$k} = $stream;

    return $stream;
}

sub parse_response {
    my ($self, $resp) = @_;

    my $neck_pos = index($resp, "${CRLF}${CRLF}");
    my $body = substr($resp, $neck_pos+4);
    my $head = substr($resp, 0, $neck_pos);

    my $proto = substr($head, 0, 8);
    my $status_code = substr($head, 9, 3);
    substr($head, 0, index($head, $CRLF) + 2, ""); # 2 = length($CRLF)

    my $header;
    for (split /${CRLF}/o, $head) {
        my ($key, $value) = split /: /, $_, 2;
        $header->{$key} = $value;
    }

    my %data = (
        proto => $proto,
        code  => $status_code,
        headers => $header,
        body   => $body,
    );

    if ($data{code} == 200 and length($body) != $data{headers}{'Content-Length'}) { # data is incompleted
        my $type = length($body) < $data{headers}{'Content-Length'} ? 'incomplete' : 'overflooded';
        %data = (error => 1, message => 'incomplete');
        return wantarray ? %data : \%data;
    }

    if ($data{code} == 200 and $data{headers}->{'Content-Type'} =~ 'javascript') {
        $data{json} = $self->{json}->decode($body);
    }

    return wantarray ? %data : \%data;
}

sub __ua {
    my $self = shift;

    return $self->{ua} if exists $self->{ua};

    my $ua = Mojo::UserAgent->new;
    $ua->max_redirects(3);
    $ua->inactivity_timeout($self->{timeout});
    $ua->proxy->detect; # env proxy
    $self->{ua} = $ua;

    return $ua;
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
        publish_callback => sub {
            my ($data) = @_;

            # sample $data
            # {
            #     'headers' => {
            #                    'Connection' => 'keep-alive',
            #                    'Content-Length' => 30,
            #                    'Date' => 'Wed, 03 Sep 2014 13:31:39 GMT',
            #                    'Cache-Control' => 'no-cache',
            #                    'Access-Control-Allow-Methods' => 'GET',
            #                    'Content-Type' => 'text/javascript; charset="UTF-8"',
            #                    'Access-Control-Allow-Origin' => '*'
            #                  },
            #     'body' => '[1,"Sent","14097510998021530"]',
            #     'json' => [
            #                 1,
            #                 'Sent',
            #                 '14097510998021530'
            #               ],
            #     'code' => 200,
            #     'proto' => 'HTTP/1.1'
            # };
        }
    );

    # publish
    $pubnub->publish({
        messages => ['message1', 'message2']
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

PubNub::PubSub is Perl library for rapid publishing of messages on PubNub.com based on L<Mojo::IOLoop>

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

optional. check every response on publish.

=item * publish_timeout

publish stream timeout. default is 1 hour = 3600

=item * subscribe_timeout

subscribe stream timeout. default is 1 hour = 3600

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
        messages => ['message1', 'message2']
    });
    $pubnub->publish({
        channel  => 'sandbox2', # optional, if not applied, the one in ->new will be used.
        messages => ['message3', 'message4']
    });

Note if you need callback, please pass it when do ->new with B<publish_callback>.

=head2 history

fetches historical messages of a channel

    my $history = $pubnub->history({
        count => 20,
        reverse => "false"
    });
    # $history is [ ['message1', ...], timetoken1, timetoken2 ]

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
