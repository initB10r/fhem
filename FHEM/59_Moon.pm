use strict;
use warnings;
use Astro::MoonPhase;
use Astro::Coord::ECI;
use Astro::Coord::ECI::Moon;
use Astro::Coord::ECI::Utils qw{deg2rad};
use POSIX qw{strftime};

package main;

#####################################
sub Moon_Initialize($) {
  my ($hash) = @_;
  $hash->{DefFn}   = "Moon_Define";
  $hash->{UndefFn} = "Moon_Undef";
  $hash->{SetFn}   = "Moon_Set";
  $hash->{AttrList}=  "scale disableTxt:Yes pathToPictures " . $readingFnAttributes;
  $hash->{FW_detailFn}  = "Moon_detailFn";
}

###################################
sub Moon_Set($@) {
  my ($hash, @a) = @_;
  my $cmd= $a[1];

  # usage check
  if((@a == 2) && ($a[1] eq "update")) {
     $hash->{fhem}{nxtUpdtTs}= 0; # force update
     Moon_GetUpdate($hash);
     return undef;
  } else {
    return "Unknown argument $cmd, choose one of update:noArg";
  }
}

#####################################
sub Moon_Define($$) {
  my ($hash, $def) = @_;
  my @a = split( "[ \t][ \t]*", $def );
  my $name 		= $a[0];

  $hash->{STATE} = "Initialized";
  $hash->{NAME}	= $name;
  $hash->{VERSION}	= "0.0.1";

  InternalTimer(gettimeofday()+5, "Moon_GetUpdate", $hash, 0);
  return undef;
}

#####################################
sub Moon_GetUpdate($)
{
	my ($hash)		= @_;
	RemoveInternalTimer($hash);
	InternalTimer(gettimeofday()+14400, "Moon_GetUpdate", $hash, 0);

	my $name		= $hash->{NAME};
  Log3 $hash, 5, "[$hash->{NAME}] update startet";

  delete ($hash->{READINGS});
	readingsBeginUpdate($hash); #start update

	my ( $MoonPhase,
     $MoonIllum,
     $MoonAge,
     $MoonDist,
     $MoonAng,
     $SunDist,
     $SunAng ) = Astro::MoonPhase::phase();
	$MoonIllum *= 100;
	$MoonPhase *= 100;

  readingsBulkUpdate($hash, "Belichtung", $MoonIllum);
  readingsBulkUpdate($hash, "Mondphase", $MoonPhase);
  readingsBulkUpdate($hash, "Mondalter", $MoonAge);
  readingsBulkUpdate($hash, "MondDistanz", $MoonDist);
  readingsBulkUpdate($hash, "MondWinkel", $MoonAng);

  my $moonrise = "";
	my $moonset = "";
  my $long = deg2rad (AttrVal("global", "longitude", "13.413215"));
  my $lat  = deg2rad (AttrVal("global", "latitude", "52.521918"));
  my $alt  = AttrVal("global", "altitude", "100") / 1000;

  Log3 $hash, 5, "[$hash->{NAME}] lat: $lat long: $long alt: $alt";

	my $moon = Astro::Coord::ECI::Moon->new ();
 	my $sta = Astro::Coord::ECI->
     		universal (time ())->
     		geodetic ($lat, $long, $alt);
 	my ($time, $rise) = $sta->next_elevation ($moon);
  Log3 $hash, 5, "[$hash->{NAME}] time berechnung: " . time() . " time: $time rise: $rise";


 	if ($rise == 1)
 	{
 		$moonrise = POSIX::strftime ("%H:%M", localtime $time);
 	} else {
 		$moonset = POSIX::strftime ("%H:%M", localtime $time);
 	}

  Log3 $hash, 5, "[$hash->{NAME}] Mondaufgang: $moonrise";
  Log3 $hash, 5, "[$hash->{NAME}] Monduntergang: $moonset";

	$sta = Astro::Coord::ECI->
     		universal ($time)->
     		geodetic ($lat, $long, $alt);
	($time, $rise) = $sta->next_elevation ($moon);
  Log3 $hash, 5, "[$hash->{NAME}] time: $time rise: $rise";

 	if ($rise == 1)
  {
 		$moonrise = POSIX::strftime ("%H:%M", localtime $time);
 	} else {
 		$moonset = POSIX::strftime ("%H:%M", localtime $time);
 	}
  Log3 $hash, 5, "[$hash->{NAME}] Mondaufgang: $moonrise";
  Log3 $hash, 5, "[$hash->{NAME}] Monduntergang: $moonset";

  readingsBulkUpdate($hash, "Mondaufgang", $moonrise);
  readingsBulkUpdate($hash, "Monduntergang", $moonset);

	my $bildNR = POSIX::floor($MoonAge * 99 / 29.5);

  readingsBulkUpdate($hash, "BildNr", $bildNR);
  my $pathToPictures = AttrVal($name, "pathToPictures", "/fhem/images/phasenbilder/");
  readingsBulkUpdate($hash, "ftui", "$pathToPictures$bildNR.png");
  readingsEndUpdate($hash,1); #end update

  Moon_STATE($hash,$bildNR);

  Log3 $hash, 5, "[$hash->{NAME}] update beendet";
}

#####################################
sub Moon_Undef($$) {
  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);
  return undef;
}

#####################################
sub Moon_STATE($$) {
  my ($hash, $bildNR) = @_;

  if (($bildNR > 0 and $bildNR < 4) or ($bildNR > 97 and $bildNR < 100))
  {
    $hash->{STATE}	= "Neumond";
  } elsif ($bildNR >= 23 and $bildNR <= 27 )
	{
		$hash->{STATE}	= "zunehmender Halbmond";
  } elsif ($bildNR >= 4 and $bildNR <= 47 )
	{
		$hash->{STATE}	= "zunehmender Mond";
  } elsif ($bildNR >= 48 and $bildNR <= 52 )
	{
		$hash->{STATE}	= "Vollmond";
  } elsif ($bildNR >= 73 and $bildNR <= 77 )
	{
		$hash->{STATE}	= "abnehmender Halbmond";
  } elsif ($bildNR >= 53 and $bildNR <= 97 )
	{
		$hash->{STATE}	= "abnehmender Mond";
  } else
	{
		$hash->{STATE}	= "<no definition>";
	}
  Log3 $hash, 5, "[$hash->{NAME}] bildNR: $bildNR STATE: " .$hash->{STATE};

  return undef;
}

#####################################
sub Moon_2html($) {
   my($hash) = @_;
   $hash = $defs{$hash} if( ref($hash) ne 'HASH' );
   return undef if( !$hash );

   my $name = $hash->{NAME};
   my $scale = AttrVal($name, "scale", 100);
   my $state = $hash->{STATE};
   my $bildNr = ReadingsVal( $name, "BildNr", "" );
   my $disableTxt = AttrVal($name, "disableTxt", "No");
   my $pathToPictures = AttrVal($name, "pathToPictures", "/fhem/images/phasenbilder/");
   my $ret;

   $ret .= "<div style='width:".$scale."px; text-align: center;'>";

   $ret .= "<img src='$pathToPictures$bildNr.png\' width='$scale' height='$scale'>";
   if ($disableTxt eq "No") { $ret .= "<br>$hash->{STATE}" }
   $ret .= "</div>";

   $hash->{fhem}->{cached} = $ret;

  return $ret;
}

#####################################
sub Moon_detailFn(){
  my ($FW_wname, $d, $room, $pageHash) = @_; # pageHash is set for summaryFn.
  my $hash = $defs{$d};

#  $hash->{mayBeVisible} = 1;
  return Moon_2html($d);
}

#####################################
1;
