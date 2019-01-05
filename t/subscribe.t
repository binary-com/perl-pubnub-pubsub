use strict;
use Test::More;
use PubNub::PubSub;

# not 100% deterministic e.g. on a very slow system, but $pubnub->subscribe should block forever if it's working, and the eval should quickly exit if not.
# this is intended to catch cases like: Can't locate object method "prepare" via package "0" (perhaps you forgot to load "0"?) at /usr/share/perl5/Mojo/UserAgent.pm line 322

$SIG{ALRM} = sub { die('ok') };

eval {
	my $pubnub = PubNub::PubSub->new(
		host => 'test.invalid', # iana reserved
		timeout => 1,
	);

	alarm(1);

	my $result = $pubnub->subscribe(
		channel => 'foo',
		sub_key => 'bar',
		callback => sub { return(0); },
	);
};

like $@, qr/^ok /;

done_testing;
