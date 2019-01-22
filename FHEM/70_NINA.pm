################################################################
#
#  Copyright notice
#
#  (c) 2018 Marc Bauschlicher
#
##############################################################################
#  Verbose levels:
#
#  0 = Log start/stop and initialization messages
#  1 = Log errors
#  2 = Log counters and warnings
#  3 = Log events and runtime information
#
# Duisburg
# https://warnung.bund.de/bbk.status/status_051120000000.json
# [
# {"bucketname":"bbk.mowas","status":0,"ref":[]},
# {"bucketname":"bbk.dwd","status":1,"ref":["6ef287ad66a75f30a76fd766bdb48eb8d6bca6a55475486b2145b6dce1a6f1b4"]},
# {"bucketname":"bbk.lhp","status":1,"ref":["HOCHWASSERZENTRALEN.DE.NW"]}
# ]
#
# https://warnung.bund.de/bbk.dwd/60cec874be00ce28cb2a674ed1e3c104f26fcbf3e9704b8af97fa8e915756dea.json
# https://warnung.bund.de/bbk.lhp/HOCHWASSERZENTRALEN.DE.NW.json
#
#
# Kreis Steinburg
# https://warnung.bund.de/bbk.status/status_010610000000.json 
# [
# {"bucketname":"bbk.lhp","status":0,"ref":[]},
# {"bucketname":"bbk.dwd","status":1,"ref":["eaef143b81d1ce56bdff67843ea688a8cf23fe5639fdbfd39847bc590173f4fc"]},
# {"bucketname":"bbk.mowas","status":1,"ref":["DE-SH-EH-S028-20180419-002"]}
# ]
# 
# https://warnung.bund.de/bbk.dwd/eaef143b81d1ce56bdff67843ea688a8cf23fe5639fdbfd39847bc590173f4fc.json
# https://warnung.bund.de/bbk.mowas/DE-SH-EH-S028-20180419-002.json
#
# Berlin Fenster und Türen schließen
# {"identifier":"DE-BR-B-S017-20180430-003","msgType":"Cancel","code":["1.0","medien_regional","nina","sirene","warnmittel"],"references":"DE-BR-B-S017,DE-BR-B-S017-20180430-002,2018-04-30T00:00:00+00:00","sender":"DE-BR-B-S017","scope":"Public","sent":"2018-04-30T17:08:36+02:00","status":"Actual","info":[{"severity":"Severe","area":[{"polygon":["13.2327,52.5647 13.2325,52.5638 13.2321,52.5629 13.2316,52.562 13.2309,52.5612 13.2301,52.5604 13.2292,52.5596 13.2281,52.5589 13.227,52.5583 13.2257,52.5577 13.2244,52.5573 13.223,52.5569 13.2215,52.5566 13.22,52.5563 13.2185,52.5562 13.2169,52.5562 13.2154,52.5562 13.2139,52.5564 13.2124,52.5566 13.2109,52.5569 13.2096,52.5573 13.2082,52.5578 13.207,52.5584 13.2059,52.559 13.2049,52.5597 13.204,52.5605 13.2032,52.5613 13.2025,52.5622 13.202,52.5631 13.2017,52.564 13.2014,52.5649 13.2014,52.5658 13.2015,52.5668 13.2017,52.5677 13.2021,52.5686 13.2026,52.5695 13.2033,52.5703 13.2041,52.5711 13.205,52.5719 13.2061,52.5726 13.2072,52.5732 13.2085,52.5738 13.2098,52.5742 13.2112,52.5746 13.2127,52.5749 13.2142,52.5752 13.2157,52.5753 13.2173,52.5753 13.2188,52.5753 13.2203,52.5751 13.2218,52.5749 13.2233,52.5746 13.2246,52.5742 13.226,52.5737 13.2272,52.5731 13.2283,52.5725 13.2294,52.5718 13.2303,52.571 13.231,52.5702 13.2317,52.5693 13.2322,52.5684 13.2325,52.5675 13.2328,52.5666 13.2328,52.5657 13.2327,52.5647"],"areaDesc":"Bundesland: Land Berlin"},{"areaDesc":" ","geocode":[{"valueName":"GEOCODE","value":"110000000000"}]}],"responseType":["Prepare"],"expires":"2018-04-30T23:08:36+02:00","urgency":"Immediate","parameter":[{"valueName":"sender_langname","value":"Land Berlin - Berliner Feuerwehr"}],"certainty":"Observed","description":"Dies ist die Entwarnung zur Warnung \"Großbrand in der Mertensstr. 11 in Hakenfelde\" vom 30.04.2018 gesendet durch Land Berlin - Berliner Feuerwehr. Die Warnung ist aufgehoben.<br/>Bitte Fenster und Türen schließen.<br/>","language":"DE","category":["Safety"],"event":"Gefahrenmitteilung","headline":"Entwarnung: Großbrand in der Mertensstr. 11 in Hakenfelde"}]}
##############################################################################
# $Id:$
################################################################
package main;
my $decoded="";

use strict;
use warnings;
use JSON;
use Time::Piece;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request;

sub
NINA_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}     = "NINA_Define";
  $hash->{AttrList}  = "disable:0,1 delay " . $readingFnAttributes;
}

sub
NINA_Define($$)
{
  my ($hash, $def) = @_;
  my $name=$hash->{NAME}||"";
  my @a = split("[ \t][ \t]*", $def);

  my $url = $a[2]||"";
  my $delay = $a[3]||"";
  
  $attr{$name}{delay}=$delay if $delay;

  return "Wrong syntax: use define <name> NINA <url> <poll-delay>" if(int(@a) != 4);

  $hash->{Url} = $url;

 Log3 $name, 2, "NINA Define";

  InternalTimer(gettimeofday(), "NINA_GetStatus", $hash, 0);
 
  return undef;
}

######################################

sub
NINA_GetStatus($)
{
  my ($hash) = @_;
  my $err_log='';

  my $name = $hash->{NAME}||"";
  my $URL = $hash->{Url}||"";
  my $delay=$attr{$name}{delay}||300;



    return
      if (
        IsDisabled($name)
        );
  
Log3 $name, 2, "NINA GetStatus - Delay $delay";
  
  
  InternalTimer(gettimeofday()+$delay, "NINA_GetStatus", $hash, 0);

  if(!defined($hash->{Url})) { return(""); }
  
  my $agent = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1, timeout => 25)||"";
  my $header = HTTP::Request->new(GET => $URL)||"";
  my $request = HTTP::Request->new('GET', $URL, $header)||"";
  my $response = $agent->request($request)||"";



my ($Sekunden, $Minuten, $Stunden, $Monatstag, $Monat, $Jahr, $Wochentag, $Jahrestag, $Sommerzeit) = localtime(time);
$Jahr += 1900;
my $targetTimestamp = sprintf("%02d%02d%02d_%02d%02d%02d",$Jahr,$Monat,$Monatstag,$Stunden,$Minuten,$Sekunden);

my $DebugFileName="NINA/ninaResponse_".$targetTimestamp.".json";
open FILEHANDLE, ">$DebugFileName";
print FILEHANDLE $response->{_content};
close FILEHANDLE;

  $err_log.= "Can't get $URL -- ".$response->status_line
                unless $response->is_success;

  if($err_log ne "")
  {
		Log3 $name, 1, "NINA ".$err_log;
        return("");
  }

  my $decoded = decode_json( $response->content );
  
  #used for debugging
  #print $response->content."\n";
  
  readingsBeginUpdate($hash);
  
  toReadings($hash, $decoded);
  
  readingsEndUpdate($hash,1);
  
  DoTrigger($name, undef) if($init_done);
}

sub toReadings($$;$$)                                                                
{                                                                               
  my ($hash,$ref,$prefix,$suffix) = @_;                                               
  my $name = $hash->{NAME}||"";
  $prefix = "" if( !$prefix );                                                  
  $suffix = "" if( !$suffix );                                                  
  $suffix = "_$suffix" if( $suffix );                                           

Log3 $name, 3, "NINA prefix:".$prefix;


                                                                                
  if(  ref($ref) eq "ARRAY" ) {                                                 
    while( my ($key,$value) = each $ref) {                                      
      toReadings($hash,$value,$prefix.sprintf("%02i",$key+1)."_");                        
    }                                                                           
  } elsif( ref($ref) eq "HASH" ) {                                              
    while( my ($key,$value) = each $ref) {                                      
      if( ref($value) ) {                                                       
        toReadings($hash,$value,$prefix.$key.$suffix."_");                            
      } else {
      	  readingsBulkUpdate($hash, $prefix.$key.$suffix, $value);
      }                                                                         
    }                                                                           
  }                                                                             
}                                                                               
                                                                                
                                                                                
1;
