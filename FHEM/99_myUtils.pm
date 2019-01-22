##############################################
# $Id: 99_Utils.pm 1099 2011-11-12 07:53:34Z rudolfkoenig $
package main;


use Time::Piece (); 
use Time::HiRes qw(time);
use strict;
use warnings;
use POSIX;
use Date::Parse;
use Frontier::Client;
use Try::Tiny;
use MIME::Base64;

use vars qw($FW_ME); 

sub
myUtils_Initialize($$)
{
  my ($hash) = @_;
}


##########################################################
# Messages read/Send
# 
sub
mySendMessage($$$)
{
my $myMessageType = shift;		# 0=Text, 1=Image 
my $myMessageText = shift;
my $myMessageRecipient = shift; # 0=Henny und Marc, 1=Marc,2=Henny

my $usedMode = Value("messengerType");
my $usedClient = 0; #0=both, 1=WhatsApp, 2=Telegram
my $ret = "";
 
my $WhatsAppState = Value("WhatsApp");
if ( lc($usedMode) eq 'eval' ) {
	if( lc($WhatsAppState) eq 'connected' ) {
		$usedClient = 1;
	} else {
		$usedClient = 2;
	}
}
elsif( lc($usedMode) eq "whatsapp" ) {
		$usedClient = 1;
}
elsif( lc($usedMode) eq "telegram" ) {
		$usedClient = 2;
}
elsif( lc($usedMode) eq "both" ) {
		$usedClient = 0;
}

#$ret = "Parameter: \$WhatsAppState=$WhatsAppState - \$myMessageType=$myMessageType - \$myMessageText=$myMessageText - \$myMessageRecipient=$myMessageRecipient - \$usedMode=$usedMode - \$usedClient=$usedClient";
#fhem("set telegramBot message \@Marc_Bauschlicher $ret");

if ( $usedClient==0 || $usedClient==1 ){
	$ret = 'Handy_Marc,Handy_Henny'  if ($myMessageRecipient == 0);
	$ret = 'Handy_Marc'  if ($myMessageRecipient == 1);
	$ret = 'Handy_Henny'  if ($myMessageRecipient == 2);
	
	$ret .= " send " if ($myMessageType == 0);
	$ret .= " image " if ($myMessageType == 1);
	
	$ret .= " $myMessageText";
	
	fhem("set $ret");
	}

if ( $usedClient==0 || $usedClient==2 ){
	$ret = "message " if ($myMessageType == 0);
	$ret = "sendImage " if ($myMessageType == 1);
	
	$ret .= '@381397993 @44815556'  if ($myMessageRecipient == 0);
	$ret .= '@44815556'  if ($myMessageRecipient == 1);
	$ret .= '@381397993'  if ($myMessageRecipient == 2);
	
	$ret .= " $myMessageText";
	
	fhem("set telegramBot $ret");
	}
}
 
##########################################################
# myReceiveMessage
# 
sub
myReceiveMessage($)
{
Log 3, 'Start receiving Msg';
my $myEvent = shift;
my $myId = ReadingsVal("telegramBot", "msgChatId", "");
my $myName = ReadingsVal("telegramBot", "msgChat", "");
Log 3, "vales: myName=$myName - myEvent=$myEvent";
if( lc($myEvent) eq 'msgtext: tor' ) {
	fhem("set HMW_NSK1_Toroeffner on");
	sleep(1);
	fhem("set HMW_NSK1_Toroeffner off");
	fhem "set telegramBot message \@$myId Das Tor wird geoeffnet!";
	fhem "set MyTTS tts Das Tor wird durch $myName geöffnet";
	mySendMail('post@bauschlicher.de',"Message von $myName","Das Tor wird geöffnet");
} else {
	$myEvent =~ s/msgText: /Nachricht von $myName: /;
	fhem "set MyTTS tts $myEvent";
	mySendMail('post@bauschlicher.de',"Message von $myName","$myEvent");
}

Log 3, 'End receiving Msg';
}

##########################################################




######## DebianMail  Mail auf dem RPi versenden ############ 
sub 
mySendMail 
{ 
 my $rcpt = shift;
 my $subject = shift; 
 my $text = shift; 
 my $attachment = shift; 
 my ($Sekunden, $Minuten, $Stunden, $Monatstag, $Monat,$Jahr, $Wochentag, $Jahrestag, $Sommerzeit) = localtime(time);
 my $currTime = sprintf("%02d:%02d:%02d",$Stunden,$Minuten,$Sekunden,);
 $subject = $currTime." - ".$subject;
 
#FBMail("$rcpt","$subject","$text"); 
DebianMail("$rcpt","$subject","$text","$attachment"); 
#exmail("$rcpt","$subject","$text"); 
}

######## DebianMail  Mail auf dem RPi versenden ############ 
sub 
DebianMail 
{ 
 my $rcpt = shift;
 my $subject = encode_base64(shift,''); 
 my $text = shift; 
 my $attachment = shift; 
 my $ret = "";
 my $sender = 'fhem@bauschlicher.de'; 
 my $konto = 'smtp@bauschlicher.de';
 my $passwrd = 'sm4|8Qtp12z';
 my $provider = '81.169.145.133';
 my $charSet = 'utf-8';
 
 Log 3, "sendEmail RCP: $rcpt";
 Log 3, "sendEmail Subject: $subject";
 Log 3, "sendEmail Text: $text";
 Log 3, "sendEmail Attachment: $attachment";
 Log 3, "sendEmail -f '$sender' -t '$rcpt' -u '=?$charSet?B?$subject?=' -m '$text' -s '$provider' -xu '$konto' -xp '$passwrd' -o message-charset=$charSet -o tls=yes -o message-content-type=html";

 $ret .= qx(sendEmail -f '$sender' -t '$rcpt' -u '=?$charSet?B?$subject?=' -m '$text' -s '$provider' -xu '$konto' -xp '$passwrd' -o message-charset=$charSet -o tls=yes -a $attachment);
 $ret =~ s,[\r\n]*,,g;    # remove CR from return-string 
 Log 3, "sendEmail returned: $ret"; 
}

sub exmail ($$$) 
{  
 my ($rcpt, $subject, $text) = @_;
 system("echo \"$text\" | /usr/bin/mail -s \"$subject\" \"$rcpt\""); 
} 

######## FBMail Mail auf der FB7390 versenden  ############ 
# Aufrufbeschreibung    FBMail('mail@@domain.com','Subject Test','Mailtext Test123') in fhem.cfg dann: 
# define Mail notify Fenstergriff.*|Tuersensor.* { FBMail('mail@@domain.com','Das ist der Betreff','Das ist der Mail-Body') } 

sub 
FBMail
	{ 
  	my $rcpt = $_[0]; 
	Log 3, "rcpt = $rcpt";
  	my $subject = $_[1]; 
	Log 3, "subject = $subject";
 	my $text = $_[2]; 
	Log 3, "text = $text";
  	my $ret = ""; 
  	my $tmpfile = "/var/media/ftp/fhem/log/fhem_mail.txt"; 
	$ret .=  system("/bin/echo \'$text\' > \'$tmpfile\' && /sbin/mailer -i \'$tmpfile\' -s \'$subject\' -t \'$rcpt\' && /bin/rm \'$tmpfile\'"); 
	$ret =~ s,[\r\n]*,,g;        # remove CR from return-string 
	}

sub
FritzBoxCallnr ($)
{    
   my ($callnr) = @_;
   $callnr = "ATDT".$callnr."#";
   my $ret = "ATD: " . `echo $callnr | nc 127.0.0.1 1011` ;
   InternalTimer(gettimeofday()+20, "FritzBoxHangOn", "", 0); 
   return
}

sub
FritzBoxHangOn ()
{
   my $ret = " ATH: " . `echo "ATH" | nc 127.0.0.1 1011` ;
   $ret =~ s,[\r\n]*,,g;        # remove CR from return-string
   return
}


sub
execDial ($)
{
my ($callno) = @_;
Log 3 ,"Hier: $callno";  
my $ret = `/usr/bin/ctlmgr_ctl w telcfg command/Dial '*124#$callno' &`;
Log 3 ,"$ret";  
#InternalTimer(gettimeofday()+20, "stopDial", "", 0); 
#return $ret if($ret);  
}

sub
stopDial ()
{
	my $ret = `ctlmgr_ctl w telcfg command/Hangup 1`;
   return
}



sub
execShell
{
  my $a .= $_[0];
  
#Log 3 ,"$a"; 
  #my $ret =  system($a);
     my $ret = `($a) &`;
#Log 3 ,"$ret"; 
     return $ret if($ret);  
	
}


###################################################################################
# Shadowing Section

my $groupJalousieSO = "jalousieSO";
my $groupJalousieSW = "jalousieSW";
my $groupJalousieNW = "jalousieNW";
my $shadowingCheckValues = "";	

sub 
shadowingAction($$) {
	my $targetDev = shift;		#Welche Geräte sollen gesteuert werden (EG,OG,ALL,NO,SO,SW,NW)
	my $targetAction  = shift;	#Welche Aktion soll ausgeführt werden (on,off,1,100,shadowing,threshold)
	Log 3, "start shadowingAction: \$targetDev=$targetDev - \$targetAction=$targetAction";
	
	my $targetGroup = "null";
		
	if ($targetDev eq "no"){
		$targetGroup = "jalousieNO";
		}
	elsif ($targetDev eq "so"){
		$targetGroup = "jalousieSO";
		}
	elsif($targetDev eq "sw"){
		$targetGroup = "jalousieSW";
		}
	elsif($targetDev eq "nw"){
		$targetGroup = "jalousieNW";
		}
	elsif($targetDev eq "eg"){
		$targetGroup = "jalousieEG";
		}
	elsif($targetDev eq "og"){
		$targetGroup = "jalousieOG";
		}
	elsif($targetDev eq "all"){
		$targetGroup = "jalousieAll";
		fhem("set ".$groupJalousieSO."_Status off");
		fhem("set ".$groupJalousieSW."_Status off");
		fhem("set ".$groupJalousieNW."_Status off");
		}
	if (($targetDev eq "so") || ($targetDev eq "sw") || ($targetDev eq "nw")){
			if ($targetAction eq "shadowingOn"){
				fhem("set ".$targetGroup."_Status on");
				Log 3, "Status von $targetGroup wird auf on gesetzt";
				}
			elsif($targetAction eq "shadowingOff"){
				fhem("set ".$targetGroup."_Status off");
				Log 3, "Status von $targetGroup wird auf off gesetzt";
				}		
		}
	
	#Temperatur der Aktion holen, um diese um Log anzuzeigen
	my $temperatureValue = "null";
	if(($targetAction eq "shadowingOn") || ($targetAction eq "shadowingOff")){
		$temperatureValue = ReadingsVal(AttrVal($targetGroup,"shadowingSensor","null"),"temperature","null");
		}

	Log 3, "Structure element from \$targetGroup=$targetGroup";
	my $dependencyDevice = "null";
	my $dependencyValue = "null";
	my $shadowingValue = "null";
	my $shadowingOffValue = "null";
	my $actionValue = "null";
	my $strEl = "null";
	my $strElType = "null";

	my @targetGroupDevices = split(/:/,AttrVal($targetGroup,"dependencyDevice","null"));
	for(@targetGroupDevices) {
		$strEl = $_;
		if (($targetAction eq "shadowingOn") || ($targetAction eq "1")){
			$dependencyDevice = AttrVal($strEl,"dependencyDevice","null");
			$dependencyValue = AttrVal($strEl,"dependencyValue","null");
			$shadowingValue = AttrVal($strEl,"shadowingValue","null");
			$shadowingOffValue = AttrVal($strEl,"shadowingOffValue","null");
			$strElType = InternalVal($strEl,"TYPE","");
			if (($dependencyDevice ne "null") && ($dependencyDevice ne "unused") && ($dependencyValue ne "null") && ($dependencyValue ne "unused")){ 
				Log 3, "\$dependencyDevice=$dependencyDevice - Value=Value($dependencyDevice)";
				if (Value($dependencyDevice) eq "open"){
					$actionValue = $dependencyValue;
					Log 3, "set \$dependencyValue=$dependencyValue";
					if (($targetAction eq "1")){mySendMail('marc@bauschlicher.de',"ACHTUNG shadowingControl: $strEl wurde nicht vollständig geschlossen","Grund geöffnete Tür\n\$dependencyDevice=$dependencyDevice");}
					}
				else {
					$actionValue = ($targetAction eq "shadowingOn") ? $shadowingValue : $shadowingOffValue;
				Log 3, "set other Value=$actionValue";
					}
				}
			elsif(($targetAction eq "shadowingOn")){
				$actionValue = (Value($strEl) eq "off") ? "off" : $shadowingValue;
				Log 3, "set shadowingOn Value=$actionValue";
				}
			else {
				$actionValue = $shadowingOffValue;
				}
			}
		elsif(($targetAction eq "shadowingOff")){
			$actionValue = (Value($strEl) eq "off") ? "off" : "100";
			}
		else {
			$actionValue = $targetAction;
			}		

		Log 3, "vor fhem set";
		$strElType = InternalVal($strEl,"TYPE","");
		Log 3, "\$strEl=$strEl - \$strElType=$strElType";			
		if (($strElType eq "CUL_HM") || ($actionValue eq "off") || ($actionValue eq "on")){
			Log 3, "set $strEl $actionValue";
			fhem("set $strEl $actionValue");
			}  		
		else {
#zu klären für ccu - bei 1 wird auf 2 gefahren...			
			$actionValue = "2" if($actionValue eq "1");
			Log 3, "set $strEl control $actionValue";
			fhem("set $strEl control $actionValue");
			}		
		Log 3, "Struct element is $strEl - \$dependencyDevice=$dependencyDevice - \$dependencyValue=$dependencyValue - \$shadowingValue=$shadowingValue - \$actionValue=$actionValue - strElValue=Value($strEl)";
		}
	if ((Value("mailLog") eq "on")){
		mySendMail('marc@bauschlicher.de',"shadowingAction: \$targetDev=$targetDev - \$targetAction=$targetAction - \$temperatureValue=$temperatureValue","$shadowingCheckValues");
		$shadowingCheckValues = "";
		}
	Log 3, "ende shadowingAction: \$targetDev=$targetDev - \$targetAction=$targetAction - \$temperatureValue=$temperatureValue";
	}

sub 
shadowingCheck($) {
	my $targetDev = shift;		#Welche Geräte sollen gesteuert werden (EG,OG,ALL,NO,SO,SW,NW)
	Log 3, "start shadowingCheck: $targetDev";
	
	my $checkTemp = "null";
	my $checkThresholdOn = "null";
	my $checkThresholdOff = "null";
	my $shadowingStatus = "null";
	my $checkDevice = "null";
	my $avg4Up = "null";
	my $avg4Down = "null";
	
	my $checkReturn = "null"; #return ist on=in beschattung fahren, off=aus beschattung hoch fahren, false=keine Beschattungsaktion
	
	if ($targetDev eq "so"){
		$checkTemp = ReadingsVal(AttrVal($groupJalousieSO,"shadowingSensor","null"),"temperature","null");
		$checkDevice = AttrVal($groupJalousieSO,"shadowingSensor","null");
		$avg4Up = myAverage("900", "FileLog_".$checkDevice, $checkDevice.":temperature::");
		$avg4Down = myAverage("900", "FileLog_".$checkDevice, $checkDevice.":temperature::");
		$checkThresholdOn = AttrVal($groupJalousieSO,"shadowingThresholdOn","null");
		$checkThresholdOff = AttrVal($groupJalousieSO,"shadowingThresholdOff","null");
		$shadowingStatus = Value($groupJalousieSO."_Status");
		}
	elsif($targetDev eq "sw"){
		$checkTemp = ReadingsVal(AttrVal($groupJalousieSW,"shadowingSensor","null"),"temperature","null");
		$checkDevice = AttrVal($groupJalousieSW,"shadowingSensor","null");
		$avg4Up = myAverage("900", "FileLog_".$checkDevice, $checkDevice.":temperature::");
		$avg4Down = myAverage("900", "FileLog_".$checkDevice, $checkDevice.":temperature::");
		$checkThresholdOn = AttrVal($groupJalousieSW,"shadowingThresholdOn","null");
		$checkThresholdOff = AttrVal($groupJalousieSW,"shadowingThresholdOff","null");
		$shadowingStatus = Value($groupJalousieSW."_Status");
		}
	elsif($targetDev eq "nw"){
		$checkTemp = ReadingsVal(AttrVal($groupJalousieNW,"shadowingSensor","null"),"temperature","null");
		$checkDevice = AttrVal($groupJalousieNW,"shadowingSensor","null");
		$avg4Up = myAverage("900", "FileLog_".$checkDevice, $checkDevice.":temperature::");
		$avg4Down = myAverage("900", "FileLog_".$checkDevice, $checkDevice.":temperature::");
		$checkThresholdOn = AttrVal($groupJalousieNW,"shadowingThresholdOn","null");
		$checkThresholdOff = AttrVal($groupJalousieNW,"shadowingThresholdOff","null");
		$shadowingStatus = Value($groupJalousieNW."_Status");
		}

	#returnCode
##### Wenn in Beschattung und nichts gemacht werden muss, dann einen anderen Status zurückgeben 
	if (($checkTemp eq "null") || ($checkThresholdOn eq "null") || ($checkThresholdOff eq "null") || ($shadowingStatus eq "null")){
	 	$checkReturn = "false";
	 	}
	elsif(($avg4Down >= $checkThresholdOn) && ($shadowingStatus ne "on")){
		$shadowingCheckValues = "shadowingCheck: \$checkReturn=$checkReturn - \$checkTemp=$checkTemp - \$avg4Down=$avg4Down - \$avg4Up=$avg4Up - \$checkThresholdOn=$checkThresholdOn - \$checkThresholdOff=$checkThresholdOff - \$shadowingStatus=$shadowingStatus";
	 	$checkReturn = "on";
	 	}
	elsif(($avg4Up <= $checkThresholdOff) && ($shadowingStatus eq "on")){
		$shadowingCheckValues = "shadowingCheck: \$checkReturn=$checkReturn - \$checkTemp=$checkTemp - \$avg4Down=$avg4Down - \$avg4Up=$avg4Up - \$checkThresholdOn=$checkThresholdOn - \$checkThresholdOff=$checkThresholdOff - \$shadowingStatus=$shadowingStatus";
	 	$checkReturn = "off";
	 	}
	 else{
	 	$checkReturn = "false";
	 	}

	Log 3, "ende shadowingCheck: \$checkReturn=$checkReturn - \$checkTemp=$checkTemp - \$avg4Down=$avg4Down - \$avg4Up=$avg4Up - \$checkThresholdOn=$checkThresholdOn - \$checkThresholdOff=$checkThresholdOff - \$shadowingStatus=$shadowingStatus";
	return $checkReturn; 
	}
	
sub 
shadowingControl($$$) {
	Log 3, "**********************************************************************************************";
	#Parameter holen
	my $sourceDev  = shift; 	#Ausgelöst durch wen (at,notif,manual)
	my $targetDev = shift;		#Welche Geräte sollen gesteuert werden (eg,og,all,no,so,sw,nw)
	my $targetAction  = shift;	#Welche Aktion soll ausgeführt werden (on,off,1,100,threshold)

	my $shadowingControlDisabled = Value("shadowingControlDisabled");
	my $nightMode = Value("nightMode");
	
	my $shadowingCheck = "";
	my $atCheckSo = "";
	my $atCheckSw = "";
	my $atCheckNw = "";
	
	my $myHour = Time::Piece::localtime->strftime('%H%M');

	if(($shadowingControlDisabled eq "off") && ($nightMode eq "off") && (($myHour < Value("middayBreakFrom")) || ($myHour > Value("middayBreakUntil")))){
		Log 3, "start shadowingControl: \$sourceDev=$sourceDev - \$targetDev=$targetDev - \$targetAction=$targetAction - \$myHour=$myHour";
		if ($targetAction eq "threshold"){
			$shadowingCheck = shadowingCheck($targetDev);
			if ($shadowingCheck eq "on"){
				shadowingAction("$targetDev","shadowingOn");
				}
			elsif($shadowingCheck eq "off"){
				shadowingAction("$targetDev","shadowingOff");
				}
	   		}
		elsif(($sourceDev eq "at") && ($targetAction eq "100")){
			$atCheckSo = shadowingCheck("so");
			$atCheckSw = shadowingCheck("sw");
			$atCheckNw = shadowingCheck("nw");
			if (($atCheckSo eq "false") && ($atCheckSw eq "false") && ($atCheckNw eq "false")){
				shadowingAction("all","100");
				}
			else {
				#handling SO
				if ($atCheckSo eq "on"){
					shadowingAction("so","shadowingOn");
					shadowingAction("no","shadowingOn");
					}
				elsif($atCheckSo eq "off"){
					shadowingAction("so","shadowingOff");
					shadowingAction("no","shadowingOff");
					}
				else {
					shadowingAction("so","100");
					shadowingAction("no","100");
					}
				#handling SW
				if ($atCheckSw eq "on"){
					shadowingAction("sw","shadowingOn");
					}
				elsif($atCheckSw eq "off"){
					shadowingAction("sw","shadowingOff");
					}
				else {
					shadowingAction("sw","100");
					}
				#handling NW
				if ($atCheckNw eq "on"){
					shadowingAction("nw","shadowingOn");
					}
				elsif($atCheckNw eq "off"){
					shadowingAction("nw","shadowingOff");
					}
				else {
					shadowingAction("nw","100");
					}
				}
			}
		else {
	        shadowingAction("$targetDev","$targetAction");
			}
	
		#if ((Value("mailLog") eq "on")){mySendMail('marc@bauschlicher.de',"start shadowingControl: $sourceDev - $targetDev - $targetAction","Noch kein weiterer Inhalt");}
		
		fhem("setstate fpJalousieAll $targetAction");
		
		Log 3, "ende shadowingControl***";
		}
	else {
		Log 3, "shadowingControl ist abgeschaltet";
		}
	}	


###################################################################################
# Watering Section

sub wateringCountRunning() {
	Log 3, "Start wateringCountRunning";
	my $strEl = "null";
	my $countReturn = 0;
	my $deviceState = "null";
	my @targetGroupDevices = split(/:/,AttrVal("wateringAll","dependencyDevice","null"));
		for(@targetGroupDevices) {
			$strEl = $_;
			$deviceState = Value($strEl);
			if($deviceState eq "on"){
				$countReturn++;
				Log 3, "device is on";
				}
			Log 3, "\$dependencyDevice=$strEl - Value=$deviceState";

			}

	
	Log 3, "Ende wateringCountRunning - return=$countReturn";
	return $countReturn; 

	}

sub wateringControl($$$) {
	Log 3, "*** Start wateringControl ***";
		return 1;
	#Parameter holen
	my $sourceDev  = shift; 	#Ausgelöst durch wen (at,rain)
	my $targetDev = shift;		#Welche Geräte sollen gesteuert werden (HMW_Rasen_Terrasse,HMW_Rasen_Kinder,...)
	my $targetAction  = shift;	#Welche Aktion soll ausgeführt werden (on,off)
	my $wateringThreshold =	AttrVal("wateringSettings","wateringThreshold","null");
	my $runningDevices = 0;
	my $last48hours = 0;
	my $notifText = "";
	Log 3, "*** Parameter:  Auslöser=$sourceDev - Gerät=$targetDev - Aktion=$targetAction***";

	my $wateringEnabled = Value("wateringEnabled");
	if ($wateringEnabled ne 'on') {
		Log 3, "***Abbruch wateringControl --> Parameter:  Auslöser=$sourceDev - Gerät=$targetDev - Aktion=$targetAction***";
		$notifText = "Parameter:  Auslöser=$sourceDev - Gerät=$targetDev - Aktion=$targetAction - aktive Geräte=$runningDevices - Regenmenge 48h=$last48hours - Schwellwert Niederschlag=$wateringThreshold";
		mySendMail('post@bauschlicher.de',"*** Disabled wateringControl ***","$notifText");
		Log 3, "***ENDE***";
		return 1;
		}

	if($sourceDev eq "at"){
		if ($targetAction eq "on"){
			$runningDevices = wateringCountRunning();
			$last48hours = myDiff("172800", "FileLog_Wetterstation", "4:rain::");
			}
		$notifText = "Parameter:  Auslöser=$sourceDev - Gerät=$targetDev - Aktion=$targetAction - aktive Geräte=$runningDevices - Regenmenge 48h=$last48hours - Schwellwert Niederschlag=$wateringThreshold";
		if ($targetAction eq "off" || $targetAction eq "on" && $runningDevices < 2  && $last48hours < $wateringThreshold){
		 	fhem("set $targetDev $targetAction");
			Log 3, "*** DO wateringControl *** $notifText";
			mySendMail('post@bauschlicher.de',"*** DO AT wateringControl ***","$notifText");
			}
		elsif ($runningDevices >= 2) {
			Log 3, "*** ACHTUNG AT wateringControl - zuviele angeschaltete Geräte *** $notifText";
			mySendMail('post@bauschlicher.de',"*** ACHTUNG AT wateringControl - zuviele angeschaltete Geräte ***","$notifText");
			}	
		elsif ($last48hours >= $wateringThreshold) {
			Log 3, "*** ACHTUNG AT wateringControl - Hoher Niederschlag - Bewässerung nicht aktiv *** $notifText";
			mySendMail('post@bauschlicher.de',"*** ACHTUNG AT wateringControl - Hoher Niederschlag - Bewässerung nicht aktiv ***","$notifText");
			}
		}
	elsif ($sourceDev eq "rain") {
		Log 3, "*** DO RAIN wateringControl ***";
		mySendMail('post@bauschlicher.de',"*** DO RAIN wateringControl ***","$notifText");
		}
	else {
		Log 3, "*** ACHTUNG wateringControl - invalid sourceDev ***";
		mySendMail('post@bauschlicher.de',"*** ACHTUNG wateringControl - invalid sourceDev  ***","$notifText");
		}

	Log 3, "*** Ende wateringControl ***";
	}	

sub isRaining($){
	my $currValue = shift;
	my $rainingValue = substr $currValue, 11, 1;	

	my $myDateTime1 = str2time(ReadingsTimestamp("isRaining", "state", 0));
	my $myDateTime2 =  int time;
	my $myTimeDif = $myDateTime2-$myDateTime1;
	my $rainMM;
	my $notifText = "";
	
	Log 3, "myDateTime1 $myDateTime1";
	Log 3, "myDateTime2 $myDateTime2";
	Log 3, "myDateTime4 $myTimeDif";
	
	if ((Value("isRaining") eq "0") && ("$rainingValue" eq "1")) {
		fhem("set isRaining $rainingValue");
		wateringControl("rain","all","on");
		$notifText = "Es hat seit @{[getDateFromTime($myTimeDif)]} nicht mehr geregnet.";
		Log 3, "Wetterstation - Es regnet - $notifText";
		mySendMail('post@bauschlicher.de',"Wetterstation - Es regnet","$notifText");
		}
	if ((Value("isRaining") eq "1") && ("$rainingValue" eq "0")) {
		fhem("set isRaining $rainingValue");
		wateringControl("rain","all","off");
		$rainMM=myDiff("$myTimeDif", "FileLog_Wetterstation", "4:rain::");
		$notifText = "Es hat @{[getDateFromTime($myTimeDif)]} geregnet. Die Niederschlagsmenge beträgt $rainMM mm.";
		Log 3, "Wetterstation - Es regnet nicht mehr - $notifText";
		mySendMail('post@bauschlicher.de',"Wetterstation - Es regnet nicht mehr","$notifText");
		}
	}

sub listNextAt($){
	Log 3, FormatTimeStamp("1407027600");
	my ($keep) = @_;
	my ($l,$n,@r,$v);
	$v = $defs{"HMW_Bauerngarten_OFF"}{STATE};
	Log 3, "$v";
	my @ats=devspec2array("TYPE=at");
	foreach(@ats) {
		Log 3, "@ats";
		$n = $_;
		$v = $defs{HMW_Bauerngarten_OFF}{TRIGGERTIME_FMT};
		$l = $v.' '.$n;
		push @r, $l;
	}
	if($#r >= 0) {
		@r = sort(@r);
		splice @r, $keep; 
		return join("\n", @r);
	} else {
		return;
	}
}

sub checkWateringThreshold() {
	my $wateringThreshold =	AttrVal("wateringSettings","wateringThreshold","null");
	my $last48hours = myDiff("172800", "FileLog_Wetterstation", "4:rain::");
	Log 3, "$wateringThreshold";
	Log 3, "$last48hours";
	
	if($last48hours lt $wateringThreshold){
		Log 3, "OK";
		} 
	else {
		Log 3, "NOK";
		} 	
	}

###################################################################################
# HM485 Section
sub 
myHM485Control($$) {
	my $sourceDev = shift;
	my $sourceAction  = shift;	#Welche Aktion soll ausgeführt werden (on,off)

	my $targetDev = AttrVal($sourceDev,"dependencyDevice","null"); #Welche Geräte sollen gesteuert werden (00009067=RS485HS12-7),000093BA=RS485HSSA2)
	my $targetPort = AttrVal($sourceDev,"dependencyValue","null"); #Welche Geräte sollen gesteuert werden (welcher Ausgänge usw.)

#if(defined($targetPort)){print "(my \$targetPort = undef) --> defined\n";}
#else {print "(my \$targetPort = undef) --> NOT defined\n"};


	Log 3, "start hm485Control*** \$sourceDev=$sourceDev - \$targetDev=$targetDev - \$targetPort=$targetPort - \$sourceAction=$sourceAction";
	
	my $rawPort = sprintf("%02x",$targetPort);
	my $rawAction = ($sourceAction eq "on") ? "01" : "00";
	
	my $rawString = "HM485_Interface RAW $targetDev 98 00000001 78$rawPort$rawAction"; 
	Log 3, "my RAWString $rawString";
	
	fhem("set ".$rawString);
	Log 3, "ende hm485Control***";
	}


sub 
changeDriveTurn($) {
	my $newDriveTurnValue = shift;

	foreach my $strEl (devspec2array("structureJalousieAll=jalousieAll")) {
		#Log 3, "Setting device $strEl to value $newDriveTurnValue";
		Log 3, "set $strEl regSet driveTurn $newDriveTurnValue";	
		Log 3, "set $strEl getConfig";	
		Log 3, "get $strEl reg all";
		}
	}



#########################################################
#########################################################
# # # # # # # # # # # # # UTILS # # # # # # # # # # # # # 
#########################################################
#########################################################

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# myAverage
# berechnet den Mittelwert aus LogFiles über einen beliebigen Zeitraum
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
sub
myAverage($$$)
{
 my ($offset,$logfile,$cspec) = @_;
 my $period_s = strftime "%Y-%m-%d\x5f%H:%M:%S", localtime(time-$offset);
 my $period_e = strftime "%Y-%m-%d\x5f%H:%M:%S", localtime;
 #LogLevel merken 
 my $oll = $attr{global}{verbose};
 #LogLevel auf 0 
 $attr{global}{verbose} = 0; 
 my @logdata = split("\n", fhem("get $logfile - - $period_s $period_e $cspec"));
 #LogLevel auf zurücksetzen 
 $attr{global}{verbose} = $oll; 
 my ($cnt, $cum, $avg) = (0)x3;
 foreach (@logdata){
  my @line = split(" ", $_);
  if(defined $line[1] && "$line[1]" ne ""){
   $cnt += 1;
   $cum += $line[1];
  }
 }
 if("$cnt" > 0){$avg = sprintf("%0.1f", $cum/$cnt)};
 Log 4, ("myAverage: File: $logfile, Field: $cspec, Period: $period_s bis $period_e, Count: $cnt, Cum: $cum, Average: $avg");
 return $avg;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# myDiff
# berechnet die Differenz aus der ersten Zeile eines LogFiles und der letzten Zeile eines LogFiles über einen Zeitraum zwischen einem Zeitpunkt in der Vergangenheit und dem Zeitpunkt des Aufrufs
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
sub
myDiff($$$)
{
 my ($offset,$logfile,$cspec) = @_;
 my $period_s = strftime "%Y-%m-%d\x5f%H:%M:%S", localtime(time-$offset);
 my $period_e = strftime "%Y-%m-%d\x5f%H:%M:%S", localtime;
 
 #LogLevel merken 
 my $oll = $attr{global}{verbose};
 #LogLevel auf 0 
 $attr{global}{verbose} = 0; 
 my @logdata = split("\n", fhem("get $logfile - - $period_s $period_e $cspec"));
 #LogLevel auf zurücksetzen 
 $attr{global}{verbose} = $oll; 
 my ($cnt, $first, $last, $diff) = (0)x4;
 foreach (@logdata){
  my @line = split(" ", $_);
  if(defined $line[1] && "$line[1]" ne ""){
   $cnt += 1;
    if ($cnt == 1) {
     $first = $line[1];
    }
   $last = $line[1];
  }
 }
$diff = $last - $first;
Log 3, ("myDiff: File: $logfile, Field: $cspec, Period: $period_s bis $period_e, First: $first, Last: $last, Diff: $diff");
return $diff;
} 

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# plural
# Einzahl oder Mehrzahl? (Woche-Wochen, oder Tag-Tage)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
sub plural {
my ($week,$day) = @_;
my ($woche,$tag);
if ($week == 1) {
$woche = "Woche";
} else {
$woche = "Wochen";
}

if ($day == 1) {
$tag = "Tag";
} else {
$tag = "Tage";
}
return ($woche,$tag);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# getDateFromTime
# Sekunden zu Zeitangabe umrechnen
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
sub getDateFromTime {
my ($zeit_sec) = @_;
my $sec = $zeit_sec % 60;
$zeit_sec = ($zeit_sec - $sec) / 60;
my $minute = $zeit_sec % 60;
$zeit_sec = ($zeit_sec - $minute) / 60;
my $hour = $zeit_sec % 24;
$zeit_sec = ($zeit_sec - $hour) / 24;
my $day = $zeit_sec % 7;
my $week = ($zeit_sec - $day) / 7;
my ($woche,$tag) = &plural($week,$day);
return "$week $woche, $day $tag und $hour:$minute:$sec Stunden";
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# FormatTimeStamp
# Umwandlung von Timestamp nach Datum
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
sub FormatTimeStamp {
    my ($timestamp) = $_[0];
    
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = gmtime($timestamp);
    $month+=1;
    $dayOfYear+=1;
    $month = $month < 10 ? $month = "0".$month : $month;
    $dayOfMonth = $dayOfMonth < 10 ? $dayOfMonth = "0".$dayOfMonth : $dayOfMonth;
    $hour = $hour < 10 ? $hour = "0".$hour : $hour;
    $minute = $minute < 10 ? $minute = "0".$minute : $minute;
    $second = $second < 10 ? $second = "0".$second : $second;
    my $year = $yearOffset + 1900;
    return "$dayOfMonth.$month.$year $hour:$minute:$second";
}


sub
doorBell()
	{
	Log 3, 'start doorBell';

	my $url  = "http://192.168.146.11:1080/RPC2";
	my @args = (2,5);
	my $client = Frontier::Client->new( url   => $url, debug => 0, );
	my $myResult = try{$client->call('sum', @args)} catch {-1};
	
	$url  = "http://192.168.146.51:1080/RPC2";
	$client = Frontier::Client->new( url   => $url, debug => 0, );
	$myResult = try{$client->call('sum', @args)} catch {-1};
	if ($myResult == -1) {
		Log 3, "Folgender Client wurde nicht erreicht: $url ";
		$url  = "http://192.168.146.50:1080/RPC2";
		$client = Frontier::Client->new( url   => $url, debug => 0, );
		$myResult = try{$client->call('sum', @args)} catch {-1};
		}
	if ($myResult == -1) {
		Log 3, "Folgender Client wurde nicht erreicht: $url ";
		}
	mySendMail('post@bauschlicher.de',"Gehtor wurde geöffnet","Keine weiteren Inhalte");
	Log 3, 'ende doorBell';
	}


sub doorControl($) {
	Log 3, "*** Start doorControl ***";
	my $openTime = shift;
	my $openHour = 0;
	my $openMinutes = 0;
	if ($openTime==0) {
		Log 3, "*** doorControl Relais aus ***";
		fhem("set HMW_IO_TOROEFFNER off");
		sleep(3);
		Log 3, "*** doorControl Relais an ***";
		fhem("set HMW_IO_TOROEFFNER on");
		sleep(3);
		Log 3, "*** doorControl Relais aus ***";
		fhem("set HMW_IO_TOROEFFNER off");
	} else {
		Log 3, "*** doorControl AN für $openTime ***";
		fhem("set HMW_IO_TOROEFFNER on");
		
		if($openTime>=60) {
			$openMinutes = $openTime % 60;
			$openHour = ($openTime - $openMinutes) / 60;
		} else {
			$openHour = 0;
			$openMinutes = $openTime;
		}

		# Führende 0 hinzufügen falls der Wert kleiner 10 ist		
		$openHour="0".$openHour if($openHour<10);
		$openMinutes="0".$openMinutes if($openMinutes<10);
		fhem("define ALARM_TOROEFFNER_OFF at +".$openHour.":".$openMinutes.":00 {doorControl(0);;}");
	}



	Log 3, "*** Ende doorControl ***";
	}

##########################################################
# spotlightControl
# 

sub spotlightControl($) {
	Log 3, "*** Start spotlightControl ***";
	my $motionDevice = shift;
	my $motionDetectionActive = Value("motionDetectionActive");
	
	if($motionDetectionActive eq "on"){
		my $activeSeconds = 0;
		my $activeMinutes = 0;
		my $activeHour = 0;
		my $spotlightTime = AttrVal($motionDevice,"dependencyValue","10");
		my $targetDependencyDevices = AttrVal($motionDevice,"dependencyDevice","null");
		my $targetDevices = "null";
		my ($Sekunden, $Minuten, $Stunden, $Monatstag, $Monat, $Jahr, $Wochentag, $Jahrestag, $Sommerzeit) = localtime(time + $spotlightTime);
	 	my $targetDate = sprintf("%02d:%02d:%02d",$Stunden,$Minuten,$Sekunden,);
		my $mailBody = "<HTML><HEAD></HEAD><BODY>Folgende Strahler sind bis $targetDate an:<br>";
		
		my @weblinkDevices = ();	
		
		my $targetDevicesAlias ="null";
		my $targetDevicesType ="null";
			
		if($spotlightTime>=3600) {
			$activeSeconds = $spotlightTime % 60;
			$activeMinutes = (($spotlightTime - $activeSeconds) / 60) % 60;
			$activeHour = ($spotlightTime - $activeMinutes*60 - $activeSeconds) / 3600;
		} elsif($spotlightTime>=60) {
			$activeSeconds = $spotlightTime % 60;
			$activeMinutes = ($spotlightTime - $activeSeconds) / 60;
		} else {
			$activeSeconds = $spotlightTime;
			$activeMinutes = 0;
		}
		# Führende 0 hinzufügen falls der Wert kleiner 10 ist		
		$activeSeconds="0".$activeSeconds if($activeSeconds<10);
		$activeMinutes="0".$activeMinutes if($activeMinutes<10);
		$activeHour="0".$activeHour if($activeHour<10);
		
		my @targetGroupDevices = split(/\,/,$targetDependencyDevices);
		for(@targetGroupDevices) {
			$targetDevices = $_;
			$targetDevicesType = InternalVal($targetDevices,"TYPE","");
			if ("HMCCUCHN" eq uc($targetDevicesType)) {
				Log 3, "*** set targetDevices=$targetDevices on until $activeHour:$activeMinutes:$activeSeconds***";
				fhem("set $targetDevices on");
				fhem("delete SPOTLIGHT_".$targetDevices."_OFF");
				fhem("define SPOTLIGHT_".$targetDevices."_OFF at +".$activeHour.":".$activeMinutes.":".$activeSeconds." {fhem \"set $targetDevices off\";;}");
				$targetDevicesAlias = AttrVal($targetDevices,"alias","null");
				$mailBody .= " - $targetDevicesAlias<br>";
				}
			elsif ("weblink" eq lc($targetDevicesType)) {
				Log 3, "*** add $targetDevices to \@weblinkDevices***";
				push @weblinkDevices, "$targetDevices";
				}
			}
		$targetDevices = join( ",",@weblinkDevices);
  		BlockingCall("spotlightWeblinkCheckNB", "$motionDevice|$mailBody|$targetDevices", "", "", "", "");
		}
	Log 3, "*** Ende spotlightControl ***";
	}
	
sub spotlightWeblinkCheckNB($){
	my ($string) = @_;
	my ($motionDevice, $mailBody, $weblinkDevices) = split("\\|", $string);
	#Log 1, "*** motionDevice=$motionDevice***";
	#Log 1, "*** mailBody=$mailBody***";
	#Log 1, "*** weblinkDevices=$weblinkDevices***";

	my $motionDeviceAlias = AttrVal($motionDevice,"alias","null");
	my $mailImageBody = "Folgende Aufnahmen wurden zur Zeit der Auslösung gemacht:<br><table>";
	my @emailAttachments;
	my $camImages = "";
	my $camLink = "";
	my $camDevice = "";
	my $camDeviceAlias = "";
	my @camDevices = split(/\,/,$weblinkDevices);

	my $loopCounter = 0;
	my $imageCount = 5;
	while($loopCounter lt $imageCount) {
		$mailImageBody .= "<tr>";
		for(@camDevices) {
			$camDevice = $_;
			my ($Sekunden, $Minuten, $Stunden, $Monatstag, $Monat, $Jahr, $Wochentag, $Jahrestag, $Sommerzeit) = localtime(time);
			$Jahr += 1900;
		 	my $targetDate = sprintf("%02d:%02d:%02d",$Stunden,$Minuten,$Sekunden);
		 	my $targetTimestamp = sprintf("%02d%02d%02d%02d%02d%02d",$Jahr,$Monat,$Monatstag,$Stunden,$Minuten,$Sekunden);
			$camDeviceAlias = AttrVal($camDevice,"alias","null");
			$camImages = "spotlightControl_".$camDevice."_".$targetTimestamp.".jpg";
			push @emailAttachments, "/opt/fhem/cache/$camImages";
			$camLink = InternalVal($camDevice,"LINK","");
			system("wget -O /opt/fhem/cache/$camImages $camLink");
			
			$mailImageBody .= "<td>Screenshot $camDeviceAlias ($targetDate)<br><img src=\"cid:/opt/fhem/cache/$camImages\" alt=\"$camDeviceAlias\"></td>";
			}
		$loopCounter++;
		sleep(5);
		$mailImageBody .= "</tr>";
		}
	$mailBody .= "<br> $mailImageBody </table>";
	mySendEMail('marc@bauschlicher.de',"$motionDeviceAlias wurde ausgelöst","$mailBody", @emailAttachments);
	#mySendMail('marc@bauschlicher.de',"$motionDeviceAlias wurde ausgelöst","$mailBody");

	}

sub
testMySendEMail(){
	my $testBody = "Hallo Test<br><br>Hier Bild üääöü 1";
	my @emailAttachments;
	push @emailAttachments, '/opt/fhem/cache/spotlightControl_webcamHaustuere_1180126132830.jpg';
	push @emailAttachments, '/opt/fhem/cache/spotlightControl_webcamHaustuere_1180126132900.jpg';
	mySendEMail('marc@bauschlicher.de',"ACHTUNG spotlightControl: teste wurde ausgelöst","$testBody", @emailAttachments);
}


sub
mySendEMail($$$@){ 
	require sendEmail;
	Log 1, "mySendEMail Start"; 
	my ($rcpt, $subject, $text, @attachments) = @_;
	my ($Sekunden, $Minuten, $Stunden, $Monatstag, $Monat, $Jahr, $Wochentag, $Jahrestag, $Sommerzeit) = localtime(time);
	my $currTime = sprintf("%02d:%02d:%02d",$Stunden,$Minuten,$Sekunden,);
	#$subject = encode_base64( $currTime." - ".$subject,'');
	$subject = $currTime." - ".$subject;
	eMailSend($rcpt,$subject,$text,@attachments);
	Log 1, "mySendEMail Ende"; 
	}



##########################################################
# checkUnreach
# 

sub checkUnreach($$) {
	Log 3, "*** Start checkUnreach ***";
	my $unreachDevice = shift;
	my $unreachEvent = shift;
	my $unreachThreshold = AttrVal($unreachDevice,"unreachThreshold","0");
			my $activeSeconds = "30";
			my $activeMinutes = "00";
			my $activeHour = "00";
	if(lc($unreachEvent) =~ /unreach: (1|true)/)
		{
		if($unreachThreshold == 0){
			mySendMail('marc@bauschlicher.de',"UNREACH - $unreachDevice - $unreachEvent","Hallo, das Gerät $unreachDevice hat eine Nachricht nicht richtig verarbeitet. Bitte Gerät prüfen!");		
		}
		elsif(Value($unreachDevice."_checkUnreach_AT") eq "") {
			my $activeSeconds = 0;
			my $activeMinutes = 0;
			my $activeHour = 0;
			if($unreachThreshold>=3600) {
				$activeSeconds = $unreachThreshold % 60;
				$activeMinutes = (($unreachThreshold - $activeSeconds) / 60) % 60;
				$activeHour = ($unreachThreshold - $activeMinutes*60 - $activeSeconds) / 3600;
			} elsif($unreachThreshold>=60) {
				$activeSeconds = $unreachThreshold % 60;
				$activeMinutes = ($unreachThreshold - $activeSeconds) / 60;
			} else {
				$activeSeconds = $unreachThreshold;
				$activeMinutes = 0;
			}
			# Führende 0 hinzufügen falls der Wert kleiner 10 ist		
			$activeSeconds="0".$activeSeconds if($activeSeconds<10);
			$activeMinutes="0".$activeMinutes if($activeMinutes<10);
			$activeHour="0".$activeHour if($activeHour<10);
			fhem("define ".$unreachDevice."_checkUnreach_AT at +".$activeHour.":".$activeMinutes.":".$activeSeconds." {mySendMail(\"marc\\\@bauschlicher.de\",\"UNREACH - ".$unreachDevice." - ".$unreachEvent."\",\"Hallo, das Gerät ".$unreachDevice." hat eine Nachricht nicht richtig verarbeitet. Bitte Gerät prüfen!\");;}");
		 	} 
		} 
	else
		{
		fhem("delete ".$unreachDevice."_checkUnreach_AT");
		} 
	Log 3, "*** Ende checkUnreach ***";
	}


##########################################################
# WhatsApp
# 
sub
WhatsApp($$)
{
Log 3, 'Start WhatsApp';
my $myName  = shift; 
my $myAlias = AttrVal($myName,"alias",$myName); 
my $myEvent = shift;
#my $myRoom = AttrVal($myName, "room", "");
Log 3, "vales: myName=$myName - myEvent=$myEvent";
if( lc($myEvent) eq 'message: tor' ) {
	fhem("set HMW_NSK1_Toroeffner on");
	sleep(1);
	fhem("set HMW_NSK1_Toroeffner off");
	fhem "set $myName send Das Tor wird geoeffnet!";
	fhem "set MyTTS tts Das Tor wird durch $myAlias geöffnet";
	mySendMail('post@bauschlicher.de',"WhatsUp von $myAlias","Das Tor wird geöffnet");
} else {
	$myEvent =~ s/message: /Nachricht von $myAlias. /;
	fhem "set MyTTS tts $myEvent";
	mySendMail('post@bauschlicher.de',"WhatsUp von $myAlias","$myEvent");
}

Log 3, 'Ende WhatsApp';
}

sub
yowsupReconnect()
{
my $yowsupInternalState = InternalVal("WhatsApp", "STATE","");
my $rpcstate = ReadingsVal("d_ccu","rpcstate","");

Log 3, "yowsupReconnect Start: \$yowsupInternalState = $yowsupInternalState - \$rpcstate = $rpcstate";

if ($yowsupInternalState ne "connected") {
Log 3, "yowsupReconnect: try to reconnect";
	#fhem("set d_ccu rpcserver off");
	#sleep(5);
	#fhem("set d_ccu rpcserver on");
	$yowsupInternalState = InternalVal("WhatsApp", "STATE","");
	$rpcstate = ReadingsVal("d_ccu","rpcstate","");
	}
	
mySendMessage("0","yowsupReconnect: yowsupInternalState = $yowsupInternalState - rpcstate = $rpcstate","1");
Log 3, "yowsupReconnect Ende: \$yowsupInternalState = $yowsupInternalState - \$rpcstate = $rpcstate";
}


##########################################################

##########################################################
# execRinging
# 
sub
execRinging()
{
my $camImage = "./cache/ringing".rand().".jpg";
#Log 3, "camImage=$camImage";
system("wget -O $camImage http://192.168.146.24/cgi-bin/viewer/video.jpg?resolution=1280x1024");

mySendMessage("1","$camImage",0);

#system("rm $camImage");
}

##########################################################

##########################################################
# HTML Darstellung für die Unwetterwarunungen
# 
sub unwetter()
{
 my $countWarn = ReadingsVal("Untwetterzentrale","WarnCount","");
 my $unwetterText = "<div class=\"top-space-min\">";
 my $warnnumber = "";
 my $warnbild ="";
 for(my $i = 0; $i < $countWarn; $i++) {
  $warnnumber = "Warn_".$i."_ShortText";
  $warnbild = "Warn_".$i."_IconURL";
  $unwetterText .= "<div class=\"row\"><div class=\"col-2-1\"><img src=\"";
  $unwetterText .= ReadingsVal("Untwetterzentrale",$warnbild,"");
  $unwetterText .= "\" width=\"50\" height=\"50\" alt=\"unwetter\" /></div>";
  $unwetterText .= "<div class=\"top-space-mid col-3-4\">";
  $unwetterText .= ReadingsVal("Untwetterzentrale",$warnnumber,"");
  $unwetterText .= "</div></div><div class=\"newline\">&nbsp </div>";
  $warnnumber = "";
  $warnbild ="";
 }
 $unwetterText .= "</div>";
 if ($countWarn == 0) {
  $unwetterText = "Keine Unwetterwarnungen";
 }
 fhem "set unwetterText ". $unwetterText;
}

##########################################################

##########################################################
# Tägliches versenden der heutigen Kalendereinträge
# 
sub sendTodayCalendarEvents($;$;$) {
	my ($d,$o,$s) = @_;
	my $now = Time::Piece->new;
	my $todayDate = $now->strftime('%d.%m.%y');
	
	$d = "<none>" if(!$d);
	return "$d is not a Calendar instance<br>"
	if(!$defs{$d} || $defs{$d}{TYPE} ne "Calendar");
	
	my $l= Calendar_Get($defs{$d}, split("[ \t]+", "- text $o"));
	my @lines= split("\n", $l);
	my $foundEntries = 1; 
	my $ret = "Kalendereinträge vom $todayDate";
	
	# s=0 --> Einzelne Zeilen verschicken
	# s=1 --> Zusammenfassung verschicken
	foreach my $line (@lines) {
		my @fields= split(" ", $line, 3);
		my $lineDate = Time::Piece->strptime(substr($line,0,8), "%d.%m.%y");
		if ($lineDate <= $now) {
			if ($s == 1){			
				$ret .= "\n$foundEntries. Eintrag: $line";
				}
			else {
				mySendMessage("0","Kalendereinträge vom $todayDate","0") if ($foundEntries == 1);
				mySendMessage("0","$foundEntries. Eintrag: $line","0");
				}
			$foundEntries++;
			}
		}
	# keine Einträge gefunden		
	if ($foundEntries == 1){
		$ret .= "\n - keine Einträge - ";
		mySendMessage("0","$ret","0");
		}
	}

##########################################################

##########################################################
# presentNotifier
# 
sub
presentNotifier($$)
{
Log 3, 'Start presentNotifier';
my $readingName  = shift; 
my $readingValue = shift;
my $lastSeen = "";
my $notifActive = "off";

if (index($readingName,"Marc") != -1) {
	$notifActive = Value("present_Marc_StatusMsg");
	$lastSeen = ReadingsVal("unifiController","Marc-Business_last_seen","null");
	} 
elsif(index($readingName,"Henny") != -1) {
	$notifActive = Value("present_Henny_StatusMsg");
	$lastSeen = ReadingsVal("unifiController","Hennis-iPhone_last_seen","null");
	}

if ( lc($notifActive) eq 'on' ) {
	mySendMessage("0","$readingValue - $lastSeen","1");
	}

Log 3, "\$notifActive = $notifActive - \$readingValue = $readingValue";

Log 3, 'Ende presentNotifier';
}

##########################################################
# myTest
# berechnet den Mittelwert aus LogFiles über einen beliebigen Zeitraum
sub
myUtilsTest($$$)
{
Log 3, 'start myTest';
my $myName  = shift; 
my $myEvent = shift;
my $myType  = shift;
my $myValue = Value($myName);
Log 3, "vales: myName=$myName - myEvent=$myEvent - myType=$myType - Value=$myValue";
#Log 3, "inlineValues Name: $NAME *** Event: $EVENT *** Type: $TYPE ***";
	
	mySendMessage("0","Das Tor wird geoeffnet!","1");

#Log 3, execShell("aplay -Dplughw:1 ./doorbell.wav");
#my $myParameter = shift;
#my $wateringEnabled = Value("wateringEnabled");
#if ($wateringEnabled ne 'on') {
#	Log 3, "Abbruch";
#	return 1;
#	}
Log 3, 'ende myTest';
}


sub
test
	{
  	my $param1 = shift;
  	my $devName = "";
  	my @devNames = ();
	push @devNames, 'AAA';
	push @devNames, 'BBB';
	push @devNames, 'CCC';
	push @devNames, 'DDD';
  	
	for(@devNames) {
		$devName = $_;
		#print "\$devName A: $devName\n";	
		}

	my %ParamsNB = (
	param1 =>  "$param1",
	devNames => "@devNames"
	);			
  	testNB(%ParamsNB);
	}

sub
testNB
	{
	my (%arg) = @_;
   	print "Test $arg{'param1'} \n";
	#while ( my($key, $value) = each %arg ) {
   # 	print "$key = $value\n";
#		}
	}

sub
testNBDone($)
{
  my ($string) = @_;
  my ($Body, $Test) = split("\\|", $string);
  
	Log 1 ,"Body: $Body"; 
	Log 1 ,"Test: $Test"; 
  
}



sub
testEM2{
	eMailSend2('marc@bauschlicher.de',"ACHTUNG spotlightControl: teste wurde ausgelöst","testBody");
}
##########################################################

1;
