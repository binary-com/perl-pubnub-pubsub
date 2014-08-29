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
    pub_key => 'pub-c-5b5d836f-143b-48d2-882f-659e87b6c321',
    sub_key => 'sub-c-a66b65f2-2d96-11e4-875c-02ee2ddab7fe',
);

$pubnub->subscribe({
    channel => 'sandbox',
    callback => sub {
        my ($msgs, $data) = @_;
        my $should_we_stop = 0;
        foreach my $msg (@$msgs) {
            print "# Got message: $msg\n";
            $should_we_stop = 1 if $msg eq 'message1001'; # will not do exit on message1001, maybe a bit more
        }
        return ! $should_we_stop; # 1 to continue, 0 to stop
    }
});

1;