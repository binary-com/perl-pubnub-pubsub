# NAME

PubNub::PubSub - Perl library for rapid publishing of messages on PubNub.com

# SYNOPSIS

    use PubNub::PubSub;

    my $pubnub = PubNub::PubSub->new();

    # publish
    $pubnub->publish({
        pub_key => 'demo',
        sub_key => 'demo',
        channel => 'some_unique_channel_perhaps',
        messages => ['message1', 'message2'],
        callback => sub {
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
    });

    # subscribe
    $pubnub->subscribe({
        sub_key => 'demo',
        channel => 'sandbox',
        callback => sub {
            my (@messages) = @_;
            foreach my $msg (@messages) {
                print "# Got message: $msg\n";
            }
            return 1; # 1 to continue, 0 to stop
        }
    });



# DESCRIPTION

PubNub::PubSub is Perl library for rapid publishing of messages on PubNub.com based on [Mojo::IOLoop](https://metacpan.org/pod/Mojo::IOLoop)

perl clone of [https://gist.github.com/stephenlb/9496723#pubnub-http-pipelining](https://gist.github.com/stephenlb/9496723#pubnub-http-pipelining)

For a rough test:

- run perl examples/subscribe.pl in one terminal (or luanch may terminals with subscribe.pl)
- run perl examples/publish.pl in another terminal (you'll see all subscribe terminals will get messages.)

# METHOD

## new

- subscribe\_timeout

    subscribe stream timeout. default is 1 hour = 3600

- debug

    print network outgoing/incoming messages to STDERR

## subscribe

subscribe channel to listen for the messages.

    $pubnub->subscribe({
        sub_key => 'demo',
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

## publish

publish messages to channel

    $pubnub->publish({
        pub_key => 'demo',
        sub_key => 'demo',
        channel => 'some_unique_channel_perhaps',
        messages => ['message1', 'message2'],
        callback => sub {
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
    });

all __messages__ will be sent in one socket request.

__callback__ will get all original response text which means it may have two or more response text in one read. it's not that useful at all.

## history

    my $res = $pubnub->history({
        sub_key => 'demo',
        channel => 'sandbox',
        total => 100
    });

get latest history.

# AUTHOR

Binary.com <fayland@gmail.com>

# LICENSE AND COPYRIGHT

Copyright 2014- binary.com.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

[http://www.perlfoundation.org/artistic_license_2_0](http://www.perlfoundation.org/artistic_license_2_0)

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

[![Build Status](https://travis-ci.org/binary-com/perl-pubnub-pubsub.svg?branch=master)](https://travis-ci.org/binary-com/perl-pubnub-pubsub)
[![Coverage Status](https://coveralls.io/repos/binary-com/perl-pubnub-pubsub/badge.png?branch=master)](https://coveralls.io/r/binary-com/perl-pubnub-pubsub?branch=master)
[![Gitter chat](https://badges.gitter.im/binary-com/perl-pubnub-pubsub.png)](https://gitter.im/binary-com/perl-pubnub-pubsub)