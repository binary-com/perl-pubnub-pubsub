#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use PubNub::PubSub;

#  s.send('GET /publish/pub-c-5afaf11d-aa91-4a40-b0d2-77961fb3a258/sub-c-0cd3a376-28ac-11e4-95a7-02ee2ddab7fe/0/HyperLogLogDemo1/0/"'+str(id[random.randrange(0, numID-1)])+'" HTTP/1.1\r\nHost: pubsub.pubnub.com\r\n\r\n')
my $pubnub = PubNub::PubSub->new(
    pub_key => 'pub-c-5afaf11d-aa91-4a40-b0d2-77961fb3a258',
    sub_key => 'sub-c-0cd3a376-28ac-11e4-95a7-02ee2ddab7fe',
    channel => 'HyperLogLogDemo1',
    callback => sub {
        my ($res, $req) = @_;
        print "=" x 20 . "\n";
        print "REQ: $req" . "\n";
        print "=" x 20 . "\n";
        print "RES: $res" . "\n";
        print "=" x 20 . "\n";
    }
);

my @messages;
foreach (1 .. 50) {
    push @messages, "message" . int(rand(10000));
}
$pubnub->send(@messages);

1;