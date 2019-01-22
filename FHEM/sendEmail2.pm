#!/usr/bin/perl

use warnings;
use strict;
require Net::SMTP;
require IO::Socket::TLS;

IO::Socket::TLS->import(qw(SSL_VERIFY_CLIENT_ONCE));

my $user = 'smtp@bauschlicher.de';
my $pass = 'sm4|8Qtp12z';

my $server     = 'smtp.strato.de';
my $to         = 'marc@bauschlicher.de';
my $from_name  = 'fhem@bauschlicher.de';
my $from_email = 'fhem@bauschlicher.de';
my $subject    = 'test';

# Verbindungsherstellung

my $smtps =
  Net::SMTP->new( $server,
  Debug   => 1,
  
	SSL_verify_mode => SSL_VERIFY_CLIENT_ONCE(), )
  or do {
	print "Keine Kommunikation mit dem SMTP-Server 'URL' möglich";
	return 0;
  };

defined( $smtps->auth( $user, $pass ) )
  or die "Can't authenticate: $!\n";

  if ($smtps->to($to)) {
$smtps->mail($from_email);
$smtps->data();
$smtps->datasend("To: $to\n");
$smtps->datasend(qq^From: "$from_name" <$from_email>\n^);
$smtps->datasend("Subject: $subject\n\n");
$smtps->datasend("This will be the body of the message.\n");
$smtps->datasend("\n--\nVery Official Looking .sig here\n");
$smtps->dataend();
    } else {
     print "Error: ", $smtps->message();
    }

print "done\n";
