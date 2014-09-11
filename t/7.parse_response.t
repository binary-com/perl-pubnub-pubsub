#!/usr/bin/perl

use strict;
use warnings;
use PubNub::PubSub;
use Test::More;

my $pubnub = PubNub::PubSub->new(
    pub_key => 'demo',
    sub_key => 'demo',
    channel => 'sandbox'
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

# diag(Dumper(\%data)); use Data::Dumper;

is($data{code}, 200);
is($data{headers}{'Content-Type'}, 'text/javascript; charset="UTF-8"');
is($data{headers}{'Date'}, 'Fri, 29 Aug 2014 08:21:21 GMT');
is($data{body}, '[[],"14093004810481043"]');
is($data{json}->[1], '14093004810481043');

### for incomplete one
$resp_text = <<'RESP';
HTTP/1.1 200 OK
Date: Fri, 29 Aug 2014 08:21:21 GMT
Content-Type: text/javascript; charset="UTF-8"
Content-Length: 24
Connection: keep-alive
Cache-Control: no-cache
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET

[[],"140930048104810
RESP

## fix
$resp_text = join("\r\n", split(/\r?\n/, $resp_text));

%data = $pubnub->parse_response($resp_text);
ok($data{error}); # is true
is($data{message}, 'incomplete');

done_testing();

1;