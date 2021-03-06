
# $Id: 32_yowsup.pm 12219 2016-09-29 10:03:25Z justme1968 $

package main;

use strict;
use warnings;

use Socket;
use IO::Handle;

sub
yowsup_Initialize($)
{
  my ($hash) = @_;

  $hash->{ReadFn}   = "yowsup_Read";

  $hash->{DefFn}    = "yowsup_Define";
  $hash->{NotifyFn} = "yowsup_Notify";
  $hash->{UndefFn}  = "yowsup_Undefine";
  $hash->{ShutdownFn}  = "yowsup_Shutdown";
  $hash->{SetFn}    = "yowsup_Set";
  #$hash->{GetFn}    = "yowsup_Get";
  $hash->{AttrFn}   = "yowsup_Attr";
  $hash->{AttrList} = "disable:1 ";
  $hash->{AttrList} .= "cmd home nickname syncStatus ". $readingFnAttributes;
}

#####################################

sub
yowsup_Define($$)
{
  my ($hash, $def) = @_;

  my @a = split("[ \t][ \t]*", $def);

  return "Usage: define <name> yowsup"  if(@a < 2);

  my $name = $a[0];
  my $number = $a[2];

  if( !defined($number) ) {
    my $d = $modules{yowsup}{defptr}{yowsup};
    return "yowsup MASTER already defined as $d->{NAME}." if( defined($d) && $d->{NAME} ne $name );

    $modules{yowsup}{defptr}{yowsup} = $hash;

    addToDevAttrList( $name, "acceptFrom" );

  } else {
    return "no yowsup MASTER defined." if( !defined($modules{yowsup}{defptr}{yowsup}) );

    my $d = $modules{yowsup}{defptr}{$number};
    return "yowsup $number already defined as $d->{NAME}." if( defined($d) && $d->{NAME} ne $name );

    $modules{yowsup}{defptr}{$number} = $hash;

    addToDevAttrList( $name, "commandPrefix" );
    addToDevAttrList( $name, "allowedCommands" );

    addToDevAttrList( $name, "acceptFrom" ) if( $number =~ m/\./ );

    $hash->{NUMBER} = $number;
  }

  $hash->{NAME} = $name;

  $hash->{NOTIFYDEV} = "global";

  if( $init_done ) {
    yowsup_Disconnect($hash);
    yowsup_Connect($hash);
  } elsif( $hash->{STATE} ne "???" ) {
    $hash->{STATE} = "Initialized";
  }

  return undef;
}

sub
yowsup_Notify($$)
{
  my ($hash,$dev) = @_;

  my $name = $hash->{NAME};#;
  my $logName = "$name(yowsup_Notify)";
  Log3 $name, 3, "$logName: Start";

  Log3 $name, 3, "$logName: 1 DEVName $dev->{NAME}";
  Log3 $name, 3, "$logName: 2 DEVName $dev->{CHANGED}";

  return if($dev->{NAME} ne "global");
  return if(!grep(m/^INITIALIZED|REREADCFG$/, @{$dev->{CHANGED}}));

  Log3 $name, 3, "$logName: 3 vor Disconnect";
  yowsup_Disconnect($hash);
  Log3 $name, 3, "$logName: 4 vor Connect";
  yowsup_Connect($hash);
  Log3 $name, 3, "$logName: Ende";
}

sub
yowsup_reConnect($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $logName = "$name(yowsup_reConnect)";

  Log3 $name, 3, "$logName: Start";

  Log3 $name, 3, "$logName: 1 vor Disconnect";
  yowsup_Disconnect($hash);
  Log3 $name, 3, "$logName: 2 vor Connect";
  yowsup_Connect($hash);
  Log3 $name, 3, "$logName: Ende";
}

sub
yowsup_Connect($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $logName = "$name(yowsup_Connect)";

  Log3 $name, 3, "$logName: Start";


  Log3 $name, 3, "$logName:  1 $hash->{NUMBER}";
  return undef if( $hash->{NUMBER} );

  return undef if( AttrVal($name, "disable", 0 ) == 1 );

  $hash->{PARTIAL} = "";

  my ($yowsup_child, $parent);
  
  
  
 if( socketpair($yowsup_child, $parent, AF_UNIX, SOCK_STREAM || SOCK_NONBLOCK, PF_UNSPEC) ) {
    $yowsup_child->autoflush(1);
    $parent->autoflush(1);

  Log3 $name, 3, "$logName:  2 yowsup_child: $yowsup_child";
  Log3 $name, 3, "$logName:  3 parent: $parent";

    my $pid = fhemFork();

  Log3 $name, 3, "$logName:  4 pid: $pid";

    if(!defined($pid)) {
      close $parent;
      close $yowsup_child;

  Log3 $name, 3, "$logName:  5 pid not defined";

      my $msg = "$name: Cannot fork: $!";
  Log3 $name, 3, "$logName:  6 pid fork msg: $msg";
      return $msg;
    }

    if( $pid ) {
    	
  Log3 $name, 3, "$logName:  7 found pid: $pid ";
    	
      close $parent;

      $hash->{STATE} = "Connected";
      $hash->{CONNECTS}++;

      $hash->{FH} = $yowsup_child;
      $hash->{FD} = fileno($yowsup_child);
      $hash->{PID} = $pid;

      $hash->{WAITING_FOR_LOGIN} = 1;

      $selectlist{$name} = $hash;

    } else {
      close $yowsup_child;

  Log3 $name, 3, "$logName:  8 NOT found pid: $pid ";

      my $fn = $parent->fileno();
  Log3 $name, 3, "$logName:  9 fileno: $fn ";

	  close STDIN;
      open(STDIN, "<&$fn") or die "can't redirect STDIN $!";

      close STDOUT;
      open(STDOUT, ">&$fn") or die "can't redirect STDOUT $!";

      #select STDIN; $| = 1;
      #select STDOUT; $| = 1;

      #STDIN->autoflush(1);
      STDOUT->autoflush(1);


#      open(STDIN, "<&$fn") or die "can't redirect STDIN $!";

#      close STDOUT;
#      open(STDOUT, ">&$fn") or die "can't redirect STDOUT $!";
#      STDOUT->autoflush(1);

      #select STDIN; $| = 1;
      #select STDOUT; $| = 1;
      #STDIN->autoflush(1);

      close $parent;

      $ENV{PYTHONUNBUFFERED} = 1;

      if( my $home = AttrVal($name, "home", undef ) ) {
        $home = $ENV{'PWD'} if( $home eq 'PWD' );
        $ENV{'HOME'} = $home;
Log3 $name, 3, "$logName:  10 setting \$HOME to $home";
      }
        
      my $cmd = AttrVal($name, "cmd", "/opt/local/bin/yowsup-cli demos -c /root/config.yowsup --yowsup" );


$ENV{'HOME'} = $ENV{'PWD'};
$cmd = "/opt/yowsup-master/yowsup-cli demos -c /opt/yowsup-config/yowsup.config --yowsup";

Log3 $name, 3, "$logName:  11 exec cmd: $cmd";

      exec split( ' ', $cmd ) or Log3 $name, 3, "$logName:  12 exec FAILED";

Log3 $name, 3, "$logName:  12 after exec";

      POSIX::_exit(0);;
Log3 $name, 3, "$logName:  13 after POSIXExit";
    }

  } else {
    #$hash->{STATE} = "Connected";
Log3 $name, 3, "$logName:  14 socketpair FAILED";
Log3 $name, 3, "$logName:  15 retry Connect at gettimeofday()+20";
    InternalTimer(gettimeofday()+20, "yowsup_Connect", $hash, 0);
  }
  Log3 $name, 3, "$logName: Ende";
}

sub
yowsup_Disconnect($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $logName = "$name(yowsup_Disconnect)";
  Log3 $name, 3, "$logName: Start";

  return undef if( $hash->{NUMBER} );

Log3 $name, 3, "$logName: 2 RemoveInternalTimer";
  RemoveInternalTimer($hash);

  return if( !$hash->{FD} );

  if( $hash->{PID} ) {
Log3 $name, 3, "$logName: 3 Found PID";

    yowsup_Write($hash, '/disconnect' );

Log3 $name, 3, "$logName: 4 Kill PID";
    kill( 9, $hash->{PID} );
    waitpid($hash->{PID}, 0);
    delete $hash->{PID};
  }

Log3 $name, 3, "$logName: 5 Close FH: $hash->{FH}";

  close($hash->{FH}) if($hash->{FH});
Log3 $name, 3, "$logName: 6 Delete FH: $hash->{FH}";

  delete($hash->{FH});
Log3 $name, 3, "$logName: 7 Delete FD: $hash->{FH}";
  delete($hash->{FD});
Log3 $name, 3, "$logName: 8 Delete List: $selectlist{$name}";
  delete($selectlist{$name});

  $hash->{STATE} = "Disconnected";

Log3 $name, 3, "$logName: 9 Disconnected";

  $hash->{LAST_DISCONNECT} = FmtDateTime( gettimeofday() );

  Log3 $name, 3, "$logName: Ende";
}

sub
yowsup_Undefine($$)
{
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};
  my $logName = "$name(yowsup_Undefine)";
  Log3 $name, 3, "$logName: Start";

  yowsup_Disconnect($hash);

  if( $hash->{NUMBER} ) {
    delete $modules{yowsup}{defptr}{$hash->{NUMBER}};
  } else {
    delete $modules{yowsup}{defptr}{yowsup};
  }

  Log3 $name, 3, "$logName: Ende";
  return undef;
}
sub
yowsup_Shutdown($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $logName = "$name(yowsup_Shutdown)";
  Log3 $name, 3, "$logName: Start";

  yowsup_Disconnect($hash);

  Log3 $name, 3, "$logName: Ende";
  return undef;
}


sub
yowsup_Set($$@)
{
  my ($hash, $name, $cmd, @args) = @_;
  my $logName = "$name(yowsup_Shutdown)";
  Log3 $name, 3, "$logName: Start";

  my $list = "";

  if( $hash->{NUMBER} ) {
    my $phash = $modules{yowsup}{defptr}{yowsup};
    $list .= "image send" if( $phash->{PID} );

    if( $cmd eq 'image' ) {
      return "MASTER not connected" if( !$phash->{PID} );

      readingsSingleUpdate( $hash, 'sent', 'image: '. join( ' ', @args ), 1 );

      my $number = $hash->{NUMBER};
      $number =~ s/\./-/;

      my $image = shift(@args);

      return yowsup_Write( $phash, "/image send $number $image '". join( ' ', @args ) ."'" );

      return undef;
    } elsif( $cmd eq 'send' ) {
      return "MASTER not connected" if( !$phash->{PID} );

      readingsSingleUpdate( $hash, 'sent', join( ' ', @args ), 1 );

      my $number = $hash->{NUMBER};
      $number =~ s/\./-/;

      return yowsup_Write( $phash, "/message send $number '". join( ' ', @args ) ."'" );

      return undef;
    }

  } else {
    $list .= "image send raw disconnect:noArg " if( $hash->{PID} );
    $list .= "reconnect connect:noArg";

    if( $cmd eq 'raw' ) {
      return yowsup_Write( $hash, join( ' ', @args ) );

      return undef;

    } elsif( $cmd eq 'image' ) {
      readingsSingleUpdate( $hash, 'sent', 'image: '. join( ' ', @args ), 1 );

      my $number = shift(@args);
      $number =~ s/\./-/;

      my $image = shift(@args);

      return yowsup_Write( $hash, "/image send $number $image '". join( ' ', @args ) ."'" );

      return undef;

    } elsif( $cmd eq 'send' ) {
      readingsSingleUpdate( $hash, 'sent', join( ' ', @args ), 1 );

      my $number = shift(@args);
      $number =~ s/\./-/;

      if( $number =~ m/,/ ) {
        return yowsup_Write( $hash, "/message broadcast $number '". join( ' ', @args ) ."'" );
      } else {
        return yowsup_Write( $hash, "/message send $number '". join( ' ', @args ) ."'" );
      }

      return undef;

    } elsif( $cmd eq 'connect' ) {
      yowsup_Connect($hash);

      return undef;
    } elsif( $cmd eq 'disconnect' ) {
      yowsup_Disconnect($hash);

      return undef;

    } elsif( $cmd eq 'reconnect' ) {
      yowsup_Disconnect($hash);
      yowsup_Connect($hash);

      return undef;
    }
  }

  Log3 $name, 3, "$logName: Ende";
  return "Unknown argument $cmd, choose one of $list";
}


sub
yowsup_Get($$@)
{
  my ($hash, $name, $cmd) = @_;

  my $list = "devices:noArg";

  if( $cmd eq "devices" ) {
    return undef;
  }

  return "Unknown argument $cmd, choose one of $list";
}

sub
yowsup_Parse($$)
{
  my ($hash,$data) = @_;
  my $name = $hash->{NAME};
  my $logName = "$name(yowsup_Parse)";
  Log3 $name, 3, "$logName: Start";

  Log3 $name, 3, "$logName: \$data = $data";

  $hash->{TIME} = TimeNow();
  RemoveInternalTimer($hash);
  InternalTimer(gettimeofday()+60*10, "yowsup_reConnect", $hash, 0);

  if( $data =~ m/\[offline\]:/ ) {
  Log3 $name, 3, "$logName: 1 offline";
    readingsSingleUpdate( $hash, "state", 'offline', 1 ) if( ReadingsVal($name,'state','' ) ne 'offline' );

    if( $hash->{WAITING_FOR_LOGIN} ) {
    	
  Log3 $name, 3, "$logName: 2 WAITING_FOR_LOGIN";
    	
Log3 $name, 3, "$logName: 2.1 /L";
      yowsup_Write( $hash, '/L' );

Log3 $name, 3, "$logName: 2.2 /presence available";
      yowsup_Write( $hash, '/presence available' );

Log3 $name, 3, "$logName: 2.3 /presence name Schneckenhaus";
yowsup_Write( $hash, "/presence name 'Schneckenhaus'" );

Log3 $name, 3, "$logName: 2.4 /contacts sync 491736256302";
yowsup_Write( $hash, '/contacts sync 491736256302' );

Log3 $name, 3, "$logName: 2.5 /presence subscribe 491736256302";
yowsup_Write( $hash, '/presence subscribe 491736256302' );

Log3 $name, 3, "$logName: 2.6 /contacts sync 491722803039";
yowsup_Write( $hash, '/contacts sync 491722803039' );

Log3 $name, 3, "$logName: 2.7 /presence subscribe 491722803039";
yowsup_Write( $hash, '/presence subscribe 491722803039' );



      #yowsup_Write( $hash, '/ping' );

      delete $hash->{WAITING_FOR_LOGIN};
    }

  } elsif( $data =~ m/Connection Closed/s ) {

Log3 $name, 3, "$logName: 2.8 ************** connection closed ***************";
fhem("define yowsupReconnect_at at +00:15:00 {yowsupReconnect();;}");

  } elsif( $data =~ m/\[connected\]:/ ) {
  Log3 $name, 3, "$logName: 3 connected";
    readingsSingleUpdate( $hash, "state", 'connected', 1 ) if( ReadingsVal($name,'state','' ) ne 'connected' );

  } elsif( $data =~ m/Auth: Logged in!/ ) {
  Log3 $name, 3, "$logName: 4 Logged in";
    readingsSingleUpdate( $hash, "state", 'logged in', 1 ) if( ReadingsVal($name,'state','' ) ne 'logged in' );

  }

  if( $data =~ /.*PRESENCECHANGE.*State: (\S*).*From: ([\d-]*)/s ) {
   Log3 $name, 3, "$logName: 5 PRESENCECHANGE";
    my $presencestate = $1;
    my $number = $2;
    $number =~ s/-/\./;
    if( my $chash = $modules{yowsup}{defptr}{$number} ) {
      readingsSingleUpdate( $chash, "presencestate", $presencestate, 1 );
	  }

	}


  if( $data =~ m/^CHATSTATE:.*State: (\S*).*From: ([\d-]*)/s ) {
   Log3 $name, 3, "$logName: 6 CHATSTATE";
    my $chatstate = $1;
    my $number = $2;
    $number =~ s/-/\./;

    if( my $chash = $modules{yowsup}{defptr}{$number} ) {
      readingsSingleUpdate( $chash, "chatstate", $chatstate, 1 );
    }

  #} elsif( $data =~ m/\[(.*)@.*\((.*)\)\]:\[(.*)\]\s*(.*)/s ) {
  } elsif( $data =~ m/\[(.*)@.*\((.*)\)\]:\[([^\]]*)\]\s*(.*)(\nMessage)/s
    || $data =~ m/\[(.*)@.*\((.*)\)\]:\[([^\]]*)\]\s*(.*)/s ) {

   Log3 $name, 3, "$logName: 7 Message";

    my $number = $1;
    my $time = $2;
    my $id = $3;
    my $message = $4;
    my $last_sender;

    if( $number =~ m/(\d*)\/(\d*)-(\d*)/ ) {
      $number = "$2.$3";
      $last_sender = $1;
    }

    $message =~ s/\n$//;
    $message =~ s/[\b]*$//;

    my $chash = $modules{yowsup}{defptr}{$number};
    if( !$chash ) {
      my $accept_from = AttrVal($name, "acceptFrom", undef );
      if( !$accept_from || ",$accept_from," =~/,$number,/ ) {
        my $define = "$number yowsup $number";
        my $cmdret = CommandDefine(undef,$define);
        if($cmdret) {
          Log3 $name, 3, "$logName: Autocreate: An error occurred while creating device for number '$number': $cmdret";
        } else {
          #$cmdret = CommandAttr(undef,"$number alias ".$result->{$id}{name});
          $cmdret = CommandAttr(undef,"$number room yowsup");
          #$cmdret = CommandAttr(undef,"$number IODev $name");
        }

        $chash = $modules{yowsup}{defptr}{$number};
      }
    }

    if( $chash ) {
      readingsBeginUpdate($chash);
      if( $last_sender ) {
        readingsBulkUpdate( $chash, "chatstate", "received from: $last_sender" );
      } else {
        readingsBulkUpdate( $chash, "chatstate", "received" );
      }
      readingsBulkUpdate( $chash, "message", $message );
      readingsEndUpdate($chash, 1);

      my $cname = $chash->{NAME};
      if( my $prefix = AttrVal($cname, "commandPrefix", undef ) ) {
        my $cmd;
        if( $prefix eq '0' ) {
        } elsif( $prefix eq '1' ) {
          $cmd = $message;
        } elsif( $message =~ m/^$prefix(.*)/ ) {
          $cmd = $1;
        }

        if( $cmd ) {
          my $accept_from = AttrVal($cname, "acceptFrom", undef );
          if( !$accept_from || $last_sender || ",$accept_from," =~/,$last_sender,/ ) {
            Log3 $name, 3, "$cname: received command: $cmd";

            $chash->{SNAME} = $cname;
            my $ret = AnalyzeCommandChain( $chash, $cmd );

            Log3 $name, 3, "$cname: command result: $ret";

            my $number = $chash->{NUMBER};
            $number =~ s/\./-/;

            yowsup_Write( $hash, "/message send $number '$ret'" ) if( $ret );

          } else {
            Log3 $cname, 3, "$cname: commands: ". $last_sender?$last_sender:$number ." not allowed";

          }
        }

      } else {
        Log3 $cname, 3, "$cname: commands not allowed";
      }

    } else {
      Log3 $name, 3, "$logName: sender: $number not allowed";

    }

  }
  Log3 $name, 3, "$logName: Ende";
}

sub
yowsup_Read($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $logName = "$name(yowsup_Read)";
  Log3 $name, 3, "$logName: Start";

  my $buf;
  my $ret = sysread($hash->{FH}, $buf, 65536 );

  Log3 $name, 3, "$logName: 1 hashFH= $hash->{FH} ";
  Log3 $name, 3, "$logName: 2 \$ret= $ret ";
  Log3 $name, 3, "$logName: 3 \$buf= $buf ";
  
  if(!defined($ret) || $ret <= 0) {
    yowsup_Disconnect( $hash );

    Log3 $name, 3, "$logName: yowsup_Read: 4 error during sysread: $!" if(!defined($ret));
    Log3 $name, 3, "$logName: yowsup_Read: 5 end of file reached while sysread" if( $ret <= 0);

    InternalTimer(gettimeofday()+10, "yowsup_Connect", $hash, 0);
    return undef;
  }

  yowsup_Parse($hash,$buf);
  return undef;

  my $data = $hash->{PARTIAL};
  Log3 $name, 3, "yowsup/RAW: $data/$buf";
  $data .= $buf;

  $hash->{PARTIAL} = $data;
  Log3 $name, 3, "$logName: Ende";
}

sub
yowsup_Write($$)
{
  my ($hash, $data) = @_;
  my $name = $hash->{NAME};
  my $logName = "$name(yowsup_Write)";
  Log3 $name, 3, "$logName: Start";

  return "not connected" if( !$hash->{PID} );

  #my $ls = chr(226) . chr(128) . chr(168);
  #$data =~ s/\n/$ls/g;

  $data =~ s/\n/\r/g;

  Log3 $name, 3, "$logName: 1 sending $data";

  syswrite $hash->{FH}, $data ."\n";

  Log3 $name, 3, "$logName: Ende";
  return undef;
}


sub
yowsup_Attr($$$)
{
  my ($cmd, $name, $attrName, @params) = @_;
  my ($attrVal) = @params;

  my $orig = $attrVal;

  if($attrName eq "allowedCommands" && $cmd eq "set") {
    my $aName = "allowed_$name";
    my $exists = ($defs{$aName} ? 1 : 0);
    AnalyzeCommand(undef, "defmod $aName allowed");
    AnalyzeCommand(undef, "attr $aName validFor $name");
    AnalyzeCommand(undef, "attr $aName $attrName ".join(" ",@params));
    return "$name: ".($exists ? "modifying":"creating").
                " device $aName for attribute $attrName";

  } elsif( $attrName eq "disable" ) {
    my $hash = $defs{$name};
    yowsup_Disconnect($hash);
    if( $cmd eq "set" && $attrVal ne "0" ) {
      $attrVal = 1;

    } else {
      $attr{$name}{$attrName} = 0;
      yowsup_Connect($hash);

    }
  } elsif( $attrName eq "cmd" ) {
    my $hash = $defs{$name};
    if( $cmd eq "set" ) {
      $attr{$name}{$attrName} = $attrVal;
    } else {
      delete $attr{$name}{$attrName};
    }

    yowsup_Disconnect($hash);
    yowsup_Connect($hash);
  }


  if( $cmd eq "set" ) {
    if( !defined($orig) || $orig ne $attrVal ) {
      $attr{$name}{$attrName} = $attrVal;
      return $attrName ." set to ". $attrVal;
    }
  }

  return;
}

1;

=pod
=item summary    interface to the yowsup librbary (for whatsapp)
=item summary_DE Interface zur yowsup Bibliothek (f&uuml;r WhatsApp)
=begin html

<a name="yowsup"></a>
<h3>yowsup</h3>
<ul>
  Module to interface to the yowsup library to send and recive WhatsApp messages.<br><br>

  Notes:
  <ul>
    <li>Probably only works on linux/unix systems.</li>
  </ul><br>

  <a name="yowsup_Define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; yowsup</code><br>
    <br>

    Defines a yowsup device.<br><br>

    Examples:
    <ul>
      <code>define WhatsApp yowsup</code><br>
    </ul>
  </ul><br>

  <a name="yowsup_Set"></a>
  <b>Set</b>
  <ul>
    <li>image [&lt;number&gt;] &lt;path&gt; [&lt;text&gt;]<br>
      sends an image with optional text. &lt;number&gt; has to be given if sending via master device.</li>
    <li>send [&lt;numner&gt;] &lt;text&gt;<br>
      sends &lt;text&gt;. &lt;number&gt; has to be given if sending via master device.</li>
  </ul><br>

  <a name="yowsup_Attr"></a>
  <b>Attributes</b>
  <ul>
    <li>cmd<br>
      complette commandline to start the  yowsup cli client<br>
      eg: attr WhatsApp cmd /opt/local/bin/yowsup-cli demos -c /root/config.yowsup --yowsup</li>

    <li>home<br>
      set $HOME for the started yowsup process<br>
      PWD -> set to $PWD<br>
      anything else -> use as $HOME</li>

    <li>nickname<br>
      nickname that will be send as sender</li>

    <li>acceptFrom<br>
      comma separated list of contacts (numbers) from which messages will be accepted</li>

    <li>commandPrefix<br>
      not set -> don't accept commands<br>
      0 -> don't accept commands<br>
      1 -> allow commands, every message is interpreted as a fhem command<br>
      anything else -> if the message starts with this prefix then everything after the prefix is taken as the command</li>

    <li>allowedCommands<br>
      A comma separated list of commands that are allowed from this contact.<br>
      If set to an empty list <code>, (i.e. comma only)</code> no commands are accepted.<br>
      <b>Note: </b>allowedCommands should work as intended, but no guarantee
      can be given that there is no way to circumvent it.</li>
  </ul>
</ul>

=end html
=cut

