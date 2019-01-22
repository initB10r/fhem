#!/usr/bin/perl
# Frontier::Daemon installation
#>perl -MCPAN -e shell
#>install  Frontier::RPC2
#>install  PAR::Packer
#C:\> cpan
#cpan> look PAR::Packer
#C:\Dwimperl\cpan\build\PAR-Packer-1.014-81Pw9j> perl Makefile.pl
#C:\Dwimperl\cpan\build\PAR-Packer-1.014-81Pw9j> dmake -f Makefile install
#
#Leave the shell open and follow the path (may vary, depending on your system):
#
#C:\Dwimperl\cpan\build\PAR-Packer-1.014-81Pw9j\myldr
#
#There you'll find a file named 'Makefile' (the one without the .pl ending). Search the file for the string 'C:./Program' (somewhere near the end) and delete this part. Finally run.
#
#C:\Dwimperl\cpan\build\PAR-Packer-1.014-81Pw9j> dmake -f Makefile install

# sum() server
     
use strict;
use warnings;
use Frontier::Daemon;

my $d = Frontier::Daemon->new(
      LocalPort => 1080,
      methods => {
      sum => \&sum,
      }#,
     # LocalAddr => '192.168.146.31'
) or die "Cannot start HTTP server $!\n"  ;
    
sub sum {
  my ($arg1, $arg2) = @_;
  system("aplay -Dplughw:1 ./doorbell.wav");
  return $arg1 + $arg2;
}

