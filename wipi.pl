#!/usr/bin/env perl

use strict;
use warnings;
use Config::PL;
use Furl;
use Device::SerialPort;
use Math::Decimal qw/is_dec_number dec_canonise/;
use Time::Piece;

use utf8;
binmode STDOUT, ":utf8";

my $config = config_do 'config.pl';
my $furl   = Furl->new();

my $last_hms       = 0;
my $last_is_stable = '';
my $last_weight    = '';
sub transmit {
    my ($is_stable, $weight) = @_;

    my $t = localtime;
    my $hms = $t->hour * 10000 + $t->min * 100 + $t->sec;
    if ($last_is_stable eq $is_stable and $last_weight eq $weight){
        return if $last_hms == $hms;
    }

    my $res = $furl->post(
        $config->{post_url},
        [],
        [wi_id => $config->{wipi_name}, stable => $is_stable, weight => $weight, ],
    );
    if ($res->code == 200){
        $last_is_stable = $is_stable;
        $last_weight    = $weight;
        $last_hms       = $hms;
    }else{
        warn 'weight transmit failed';
    }
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
my ($blocking, $in_bytes, $out_bytes, $errors);
while (1){
    ($blocking, $in_bytes, $out_bytes, $errors) = $port->status;
    next unless $in_bytes;

    ($cnt, $reads) = $port->read($in_bytes);
    next unless $cnt;
    $buff .= $reads;
    next if length($buff) < $config->{protocol}->{data_len};
    $idx = rindex($buff, $config->{protocol}->{delimiter});
    next if $idx < $config->{protocol}->{data_len} - 1;

    $port->purge_all;
    $buff = substr($buff, $idx - $config->{protocol}->{data_len} + 1);
    $is_stable = substr($buff, $config->{protocol}->{status_ch_pos}, 1) 
                    eq $config->{protocol}->{stable_ch} ? 1 : 0;
    $buff = substr($buff, $config->{protocol}->{weight_start}, $config->{protocol}->{weight_len}); 
    $buff =~ s/ /0/g;
    if (!is_dec_number($buff) or  $buff > 99999){
        $buff = '';
        next;
    }
    $weight = dec_canonise($buff);

    transmit($is_stable, $weight);

    if ($config->{output}){
        my $t = localtime;
        print $t->hms(':'). ' ';
        print $is_stable ? 'S' : 'U';
        print "$weight\n";
    }
}

