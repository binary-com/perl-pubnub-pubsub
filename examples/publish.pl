#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use PubNub::PubSub;
use Time::HiRes qw/time/;

srand();
my $total_message = 50000 + int(rand(50000));

#  s.send('GET /publish/pub-c-5afaf11d-aa91-4a40-b0d2-77961fb3a258/sub-c-0cd3a376-28ac-11e4-95a7-02ee2ddab7fe/0/HyperLogLogDemo1/0/"'+str(id[random.randrange(0, numID-1)])+'" HTTP/1.1\r\nHost: pubsub.pubnub.com\r\n\r\n')
my $got_message = 0;
my $start_time = time();
my $pubnub = PubNub::PubSub->new(
    pub_key => 'pub-c-5b5d836f-143b-48d2-882f-659e87b6c321',
    sub_key => 'sub-c-a66b65f2-2d96-11e4-875c-02ee2ddab7fe',
);

print "Total sending $total_message\n";
my @messages;
foreach (1 .. $total_message) {
    push @messages, "message" . int(rand(100000));
}
$pubnub->publish({
    messages => \@messages,
    channel => 'sandbox',
    callback => sub {
        my ($res, $req) = @_;

        # print "=" x 20 . "\n";
        # print "REQ: $req" . "\n";
        # print "=" x 20 . "\n";
        # print "RES: $res" . "\n";
        # print "=" x 20 . "\n";

        $got_message++;
        if ($got_message == $total_message or $got_message % 1000 == 0) {
            my $duration = time() - $start_time;
            print "$got_message Spent $duration.\n";
        }
    }
});

print "Total got $got_message VS $total_message\n";
my $duration = time() - $start_time;
print "Spent $duration.\n";

1;