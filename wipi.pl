#!/usr/bin/env perl

use strict;
use warnings;
use Config::PL;
use Furl;
use Device::SerialPort;
use Math::Decimal qw/is_dec_number dec_canonise/;

use constant READ_SIZE => 512;
use utf8;
binmode STDOUT, ":utf8";

my $config = config_do 'config.pl';
my $furl   = Furl->new();

sub transmit {
    my ($is_stable, $weight) = @_;

    my $res = $furl->post(
        $config->{post_url},
        [],
        [wi_id => $config->{wipi_name}, stable => $is_stable, weight => $weight, ],
    );
    warn 'weight transmit failed' if $res->code != 200;
}

my $port = Device::SerialPort->new($config->{device}->{port}) or die "can't open serial port";
$port->baudrate($config->{device}->{baudrate});
$port->parity($config->{device}->{parity});
$port->databits($config->{device}->{databits});
$port->stopbits($config->{device}->{stopbits});
$port->handshake($config->{device}->{handshake});
$port->read_char_time(0);
$port->read_const_time(0);

my $buff = '';
my ($cnt, $reads, $idx);
my ($is_stable, $weight);
while (1){
    ($cnt, $reads) = $port->read(READ_SIZE);

    $buff .= $reads;
    $idx = rindex($buff, $config->{protocol}->{delimiter});
    next if $idx < $config->{protocol}->{data_len} - 1;

    $buff = substr($buff, $idx - $config->{protocol}->{data_len} + 1);
    $is_stable = substr($buff, $config->{protocol}->{status_ch_pos}, 1) 
                    eq $config->{protocol}->{stable_ch} ? 1 : 0;
    $buff = substr($buff, $config->{protocol}->{weight_start}, $config->{protocol}->{weight_len}); 
    $buff =~ s/ /0/g;
    next unless is_dec_number($buff);
    $weight = dec_canonise($buff);

    transmit($is_stable, $weight);

    if ($config->{output}){
        print $is_stable ? 'S' : 'U';
        print "$weight\n";
    }
}

