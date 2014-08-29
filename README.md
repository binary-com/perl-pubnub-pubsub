PubNub::PubSub - Perl library for rapid publishing of messages on PubNub.com.

Please see https://gist.github.com/stephenlb/9496723#pubnub-http-pipelining

SYNOPSIS

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
            my ($msgs, $data) = @_;
            foreach my $msg (@$msgs) {
                print "# Got message: $msg\n";
            }
            return 1; # 1 to continue, 0 to stop
        }
    });

INSTALLATION

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.

    perldoc PubNub::PubSub

You can also look for information at:

    RT, CPAN's request tracker (report bugs here)
        http://rt.cpan.org/NoAuth/Bugs.html?Dist=PubNub-PubSub

    AnnoCPAN, Annotated CPAN documentation
        http://annocpan.org/dist/PubNub-PubSub

    CPAN Ratings
        http://cpanratings.perl.org/d/PubNub-PubSub

    Search CPAN
        http://search.cpan.org/dist/PubNub-PubSub/


LICENSE AND COPYRIGHT

Copyright (C) 2014- binary.com

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

[![Build Status](https://travis-ci.org/binary-com/perl-pubnub-pubsub.svg?branch=master)](https://travis-ci.org/binary-com/perl-pubnub-pubsub)
[![Coverage Status](https://coveralls.io/repos/binary-com/perl-pubnub-pubsub/badge.png?branch=master)](https://coveralls.io/r/binary-com/perl-pubnub-pubsub?branch=master)
[![Gitter chat](https://badges.gitter.im/binary-com/perl-pubnub-pubsub.png)](https://gitter.im/binary-com/perl-pubnub-pubsub)