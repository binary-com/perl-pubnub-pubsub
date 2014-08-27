package PubNub::PubSub;

use strict;
use 5.008_005;
our $VERSION = '0.01';

use Carp;
use POSIX qw(:errno_h);
use Socket qw(PF_INET SOCK_STREAM pack_sockaddr_in inet_ntoa $CRLF SOL_SOCKET SO_ERROR);
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

sub new {
    my $class = shift;
    my %args  = @_ % 2 ? %{$_[0]} : @_;

    $args{pub_key} or croak "pub_key is required.";
    $args{sub_key} or croak "sub_key is required.";
    $args{channel} or croak "channel is required.";

    $args{host} ||= 'pubsub.pubnub.com';
    $args{port} ||= 80;
    $args{timeout} ||= 60;
    $args{__SOCKET_CACHE} = {};

    return bless \%args, $class;
}

## code are copied from Hijk with changes
sub send {
    my $self = shift;
    my @msg = @_;

    my $soc;
    my $cache_key = join($;, $$, $self->{host}, $self->{port});
    if (exists $self->{__SOCKET_CACHE}->{$cache_key}) {
        $soc = $self->{__SOCKET_CACHE}->{$cache_key};
    } else {
        ($soc, my $error) = construct_socket($self->{host}, $self->{port}, $self->{timeout});
        croak $error if defined $error; # fix to return?
        $self->{__SOCKET_CACHE}->{$cache_key} = $soc;
    }

    my $r = $self->build_http_message(@msg);
    my $total = length($r);
    my $left = $total;

    vec(my $rout = '', fileno($soc), 1) = 1;
    while ($left > 0) {
        my $nfound = select(undef, $rout, undef, undef);

        if ($nfound != 1) {
            delete $self->{__SOCKET_CACHE}->{$cache_key};
            die "select() error before write(): $!";
        }

        my $rc = syswrite($soc,$r,$left, $total - $left);
        if (!defined($rc)) {
            next if ($! == EWOULDBLOCK || $! == EAGAIN);
            delete $self->{__SOCKET_CACHE}->{$cache_key};
            shutdown($soc, 2);
            die "send error ($r) $!";
        }
        $left -= $rc;
    }

    read_http_message(fileno($soc), $self->{timeout});
}

sub read_http_message {
    my ($fd, $read_timeout, $block_size, $header, $head) = (shift,shift,10240,{},"");
    $read_timeout = selectable_timeout($read_timeout);
    my ($body,$buf,$decapitated,$nbytes,$proto);
    my $status_code = 0;
    vec(my $rin = '', $fd, 1) = 1;
    do {
        my $nfound = select($rin, undef, undef, $read_timeout);

        return (undef,0,undef,undef, 'READ_TIMEOUT')
            if ($nfound != 1 || (defined($read_timeout) && $read_timeout <= 0));

        my $nbytes = POSIX::read($fd, $buf, $block_size);
        if (!defined($nbytes)) {
            next
                if ($! == EWOULDBLOCK || $! == EAGAIN);
            die "Failed to read http " .( $decapitated ? "body": "head" ). " from socket. errno = $!"
        }

        die "Failed to read http " .( $decapitated ? "body": "head" ). " from socket. Got 0 bytes back, which shouldn't happen"
            if $nbytes == 0;

        if ($decapitated) {
            $body .= $buf;
            $block_size -= $nbytes;
        }
        else {
            $head .= $buf;
            my $neck_pos = index($head, "${CRLF}${CRLF}");
            if ($neck_pos > 0) {
                $decapitated = 1;
                $body = substr($head, $neck_pos+4);
                $head = substr($head, 0, $neck_pos);
                $proto = substr($head, 0, 8);
                $status_code = substr($head, 9, 3);
                substr($head, 0, index($head, $CRLF) + 2, ""); # 2 = length($CRLF)

                for (split /${CRLF}/o, $head) {
                    my ($key, $value) = split /: /, $_, 2;
                    $header->{$key} = $value;
                }

                if ($header->{'Content-Length'}) {
                    $block_size = $header->{'Content-Length'} - length($body);
                }
                else {
                    $block_size = 0;
                }
            }
        }
    } while( !$decapitated || $block_size > 0 );

    return ($proto, $status_code, $body, $header);
}

sub build_http_message {
    my ($self, @msg) = @_;

    my @lines;
    foreach my $msg (@msg) {
        push @lines, "GET /publish/" . $self->{pub_key} . '/' . $self->{sub_key} . '/0/' . $self->{channel} . '/0/"' . $msg . '" HTTP/1.1';
        push @lines, 'Host: pubsub.pubnub.com';
        push @lines, ''; # for \r\n
    }

    return join($CRLF, @lines);
}

sub selectable_timeout {
    my $t = shift;
    return defined($t) && $t <=0 ? undef : $t;
}

sub construct_socket {
    my ($host, $port, $connect_timeout) = @_;

    # If we can't find the IP address there'll be no point in even
    # setting up a socket.
    my $addr;
    {
        my $inet_aton = gethostbyname($host);
        return (undef, 'CANNOT_RESOLVE') unless defined $inet_aton;
        $addr = pack_sockaddr_in($port, $inet_aton);
    }

    my $tcp_proto = getprotobyname("tcp");
    my $soc;
    socket($soc, PF_INET, SOCK_STREAM, $tcp_proto) || die "Failed to construct TCP socket: $!";
    my $flags = fcntl($soc, F_GETFL, 0) or die "Failed to set fcntl F_GETFL flag: $!";
    fcntl($soc, F_SETFL, $flags | O_NONBLOCK) or die "Failed to set fcntl O_NONBLOCK flag: $!";

    if (!connect($soc, $addr) && $! != EINPROGRESS) {
        die "Failed to connect $!";
    }

    $connect_timeout = selectable_timeout( $connect_timeout );
    vec(my $rout = '', fileno($soc), 1) = 1;
    my $nfound = select(undef, $rout, undef, $connect_timeout);
    if ($nfound != 1) {
        if (defined($connect_timeout)) {
            return (undef, 'CONNECT_TIMEOUT');
        } else {
            die "select() error on constructing the socket: $!";
        }
    }

    if ($! = unpack("L", getsockopt($soc, SOL_SOCKET, SO_ERROR))) {
        die $!;
    }

    return $soc;
}

1;
__END__

=encoding utf-8

=head1 NAME

PubNub::PubSub - Blah blah blah

=head1 SYNOPSIS

  use PubNub::PubSub;

=head1 DESCRIPTION

PubNub::PubSub is

=head1 AUTHOR

Binary.com E<lt>fayland@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2014- Binary.com

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
