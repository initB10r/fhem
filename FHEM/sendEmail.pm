use strict;
use warnings;
use MIME::Lite;
use Net::SMTP::SSL;
use MIME::Base64;

my $user = 'smtp@bauschlicher.de';
my $pass = 'sMtP1m4|8<QTp2z!';
my $sender = 'fhem@bauschlicher.de'; 
my $provider = 'smtp.strato.de';
my $charSet = 'utf-8';
 
sub
eMailSend($$$@){
	my ($rcpt, $subject, $text, @attachments) = @_;
	my $attachmentName = ""; 
	$subject = encode_base64($subject,'');
 
	my $msg = MIME::Lite->new(
		From    => $sender,
		To      => $rcpt,
		Subject => "=?$charSet?B?$subject?=",
		Type    => 'multipart/mixed'
		);
                      
	$msg->attach(
		Type => "text/html; charset=$charSet",
    	Data => $text
    	);

	foreach (@attachments){
		$attachmentName = $_;
		$msg->attach(
			Type => 'image/png',
			Id   => $attachmentName,
			Path => $attachmentName,
			);
		}
	#$msg->send('smtp', $provider, AuthUser=>$user, AuthPass=>$pass);

my $smtp; 
$smtp = Net::SMTP::SSL->new($provider, Debug=>0,Port=>465) or die "Can't connect";
$smtp->auth($user, $pass) or die "Can't authenticate:".$smtp->message();
$smtp->mail($sender) or die "Error:".$smtp->message();
$smtp->to($rcpt) or die "Error:".$smtp->message();
$smtp->data() or die "Error:".$smtp->message();
$smtp->datasend($msg->as_string()) or die "Error:".$smtp->message();
$smtp->dataend() or die "Error:".$smtp->message();
$smtp->quit() or die "Error:".$smtp->message();

	
	
	}
#	eMailSend('marc@bauschlicher.de',"ACHTUNG spotlightControl: teste wurde ausgelöst","testBody");
