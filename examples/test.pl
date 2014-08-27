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
);

my @args = $pubnub->send('message1', 'message2');
use Data::Dumper;
print Dumper(\@args);

1;