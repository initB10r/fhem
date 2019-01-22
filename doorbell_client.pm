#!/usr/bin/perl 
# Testing sum()

use strict;
use warnings;
use Frontier::Client;
use Try::Tiny;

print "Start";

my $url  = "http://192.168.146.6:1080/RPC2";
my @args = (2,5);
my $client = Frontier::Client->new( url   => $url, debug => 0, );
my $myResult = try{$client->call('sum', @args)} catch {-1};

$url  = "http://192.168.146.51:1080/RPC2";
$client = Frontier::Client->new( url   => $url, debug => 0, );
$myResult = try{$client->call('sum', @args)} catch {-1};
if ($myResult == -1) {
	print "Folgender Client wurde nicht erreicht: $url ";
	$url  = "http://192.168.146.50:1080/RPC2";
	$client = Frontier::Client->new( url   => $url, debug => 0, );
	$myResult = try{$client->call('sum', @args)} catch {-1};
	}
if ($myResult == -1) {
	print "Folgender Client wurde nicht erreicht: $url ";
	}
