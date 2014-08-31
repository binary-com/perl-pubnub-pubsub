package PubNub::PubSub;

use strict;
use 5.008_005;
our $VERSION = '0.01';

use Carp;
use Mojo::IOLoop;
use Socket qw/$CRLF/;
use Mojo::JSON qw/decode_json/;
use Mojo::UserAgent;

sub new {
    my $class = shift;
    my %args  = @_ % 2 ? %{$_[0]} : @_;

    $args{pub_key} or croak "pub_key is required.";
    $args{sub_key} or croak "sub_key is required.";


    $args{host} ||= 'pubsub.pubnub.com';
    $args{port} ||= 80;
    $args{timeout} ||= 60;
    $args{subscribe_timeout} ||= 3600; # 1 hours
    $args{debug} ||= $ENV{PUBNUB_DEBUG} || 0;

    return bless \%args, $class;
}

sub publish {
    my $self = shift;
    my %params = @_ % 2 ? %{$_[0]} : @_;

    my @msg = @{ $params{messages} };
    my $channel = $params{channel} || $self->{channel};
    $channel or croak "channel is required.";

    my $callback = $params{callback}; # could be just dummy callback

    # build request
    my @lines;
    foreach my $msg (@msg) {
        push @lines, "GET /publish/" . $self->{pub_key} . '/' . $self->{sub_key} . '/0/' . $channel . '/0/"' . $msg . '" HTTP/1.1';
        push @lines, 'Host: pubsub.pubnub.com';
        push @lines, ''; # for \r\n
    }
    my $r = join("\r\n", @lines) . "\r\n";

    my $id; $id = Mojo::IOLoop->client({
        address => $self->{host},
        port => $self->{port}
    } => sub {
        my ($loop, $err, $stream) = @_;

        if ($callback) {
            $stream->on(read => sub {
                my ($stream, $bytes) = @_;

                ## parse bytes
                $callback->($bytes);
            });
        }

        # Write request
        $stream->write($r);
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub subscribe {
    my $self = shift;
    my %params = @_ % 2 ? %{$_[0]} : @_;

    my $channel = $params{channel} || $self->{channel};
    $channel or croak "channel is required.";

    my $callback = $params{callback} or croak "callback is required.";
    my $timetoken = $params{timetoken} || '0';

    sub __r {
        my ($timetoken) = @_;

        return join("\r\n",
            'GET /subscribe/' . $self->{'sub_key'} . '/' . $channel . '/0/' . $timetoken . ' HTTP/1.1',
            'Host: pubsub.pubnub.com',
            ''
        ) . "\r\n";
    }

    my $delay = Mojo::IOLoop->delay;
    my $end   = $delay->begin;
    my $handle = undef;
    my $client_id = Mojo::IOLoop->client({
        address => $self->{host},
        port => $self->{port},
        timeout => $self->{subscribe_timeout}
    } => sub {
        my ($loop, $err, $stream) = @_;
        $handle = $stream->steal_handle;
        $end->();
    });
    $delay->wait;

    # turn into stream
    my $stream = Mojo::IOLoop::Stream->new($handle)->timeout($self->{subscribe_timeout});
    my $stream_id = Mojo::IOLoop->stream($stream);

    my $buf = ''; my $last_i = 0;
    $stream->on(read => sub {
        my ($stream, $bytes) = @_;

        my %data = $self->parse_response($buf . $bytes);

        print "<<<<<<\n$bytes\n<<<<<<\n" if $self->{debug};

        ## incomplete data
        if ($data{error}) {
            if ($data{error} eq 'incomplete') { # wait a bit more for completed data
                $buf .= $bytes;
                return;
            }

            # should never happen
            $buf = '';
            return $stream->write(__r($timetoken)); # retry with old token
        }
        $buf = '';

        if ($data{json}) {
            $timetoken = $data{json}->[1];
        } else {
            # never happen
            die Dumper(\%data); use Data::Dumper;
        }

        # # test
        # if ($self->{debug} and scalar(@{ $data{json}->[0] })) {
        #     my $this_f = $data{json}->[0]->[0]; $this_f =~ s/message//;
        #     if ($this_f - $last_i != 1) {
        #         print "THRE IS A SUDDEN JUMP: $this_f vs $last_i\n";
        #         die Dumper(\%data);
        #     }
        #     my $this_l = $data{json}->[0]->[-1]; $this_l =~ s/message//;
        #     $last_i = $this_l;
        # }

        ## parse bytes
        my $rtn = $callback ? $callback->(@{ $data{json}->[0] }) : 1;
        unless ($rtn) {
            return Mojo::IOLoop->stop; # stop it
        }

        print ">>>>>>\n" . __r($timetoken) . "\n>>>>>>\n" if $self->{debug};
        $stream->write(__r($timetoken)); # never end loop
    });

    # Write request
    $stream->write(__r($timetoken));

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
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

    if (length($body) != $data{headers}{'Content-Length'}) { # data is incompleted
        my $type = length($body) < $data{headers}{'Content-Length'} ? 'incomplete' : 'overflooded';
        %data = (error => $type);
        return wantarray ? %data : \%data;
    }

    if ($data{headers}->{'Content-Type'} =~ 'javascript') {
        $data{json} = decode_json($body);
    }

    return wantarray ? %data : \%data;
}

sub history {
    my $self = shift;
    my %params = @_ % 2 ? %{$_[0]} : @_;

    my $channel = $params{channel} || $self->{channel};
    $channel or croak "channel is required.";
    my $total   = $params{total};
    $channel or croak "param total is required.";

    my $ua = $self->{ua};
    unless ($self->{ua}) {
        $ua = Mojo::UserAgent->new;
        $ua->max_redirects(3);
        $ua->inactivity_timeout(60);
        $self->{ua} = $ua;
    }

    my $proto = ($self->{port} == 443) ? 'https://' : 'http://';
    my $tx = $ua->get($proto . $self->{host} . "/history/" . $self->{sub_key} . "/$channel/0/$total");
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
        pub_key => 'demo',
        sub_key => 'demo',
    );

    # publish
    $pubnub->publish({
        messages => ['message1', 'message2'],
        channel => 'some_unique_channel_perhaps',
        callback => sub {
            my ($res) = @_;

            # ...
        }
    });

    # subscribe
    $pubnub->subscribe({
        channel => 'sandbox',
        callback => sub {
            my (@messages) = @_;
            foreach my $msg (@messages) {
                print "# Got message: $msg\n";
            }
            return 1; # 1 to continue, 0 to stop
        }
    });


=head1 DESCRIPTION

PubNub::PubSub is Perl library for rapid publishing of messages on PubNub.com based on M<Mojo::IOLoop>

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

Publish Key, required.

=item * sub_key

Subscribe Key, required.

=item * subscribe_timeout

subscribe stream timeout. default is 1 hour = 3600

=back

=head2 subscribe

subscribe channel to listen for the messages.

    $pubnub->subscribe({
        channel => 'sandbox',
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
        channel => 'some_unique_channel_perhaps',
        callback => sub {
            my ($res) = @_;

            # ... $res is raw HTTP Response (in bulk)
        }
    });

all B<messages> will be sent in one socket request.

B<callback> will get all original response text which means it may have two or more response text in one read. it's not that useful at all.

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
