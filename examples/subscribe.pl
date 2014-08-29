#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use PubNub::PubSub;
use Time::HiRes qw/time/;
use Data::Dumper;

my $got_message = 0;
my $start_time = time();
my $pubnub = PubNub::PubSub->new(
    pub_key => 'demo',
    sub_key => 'demo',
);

$pubnub->subscribe({
    channel => 'some_unique_channel_perhaps',
    callback => sub {
        my ($msgs, $data) = @_;
        foreach my $msg (@$msgs) {
            print "# Got message: $msg\n";
        }
        return 1; # 1 to continue, 0 to stop
    }
});

1;