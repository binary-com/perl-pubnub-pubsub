#!/usr/bin/perl

use strict;
use warnings;
use PubNub::PubSub;
use Test::More;

my $pubnub = PubNub::PubSub->new(
    pub_key => 'demo',
    sub_key => 'demo',
);

my $resp_text = <<'RESP';
HTTP/1.1 200 OK
Date: Fri, 29 Aug 2014 08:21:21 GMT
Content-Type: text/javascript; charset="UTF-8"
Content-Length: 24
Connection: keep-alive
Cache-Control: no-cache
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET

[[],"14093004810481043"]
RESP

## fix
$resp_text = join("\r\n", split(/\r?\n/, $resp_text));

my %data = $pubnub->parse_response($resp_text);
is($data{code}, 200);
is($data{header}{'Content-Type'}, 'text/javascript; charset="UTF-8"');
is($data{header}{'Date'}, 'Fri, 29 Aug 2014 08:21:21 GMT');
is($data{body}, '[[],"14093004810481043"]');
is($data{json}->[1], '14093004810481043');

done_testing();

1;