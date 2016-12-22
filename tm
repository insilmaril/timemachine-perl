#!/usr/bin/perl -w

# Timemachine -- written by Uwe Drechsel   uwedr@suse.de
#
my $version=3.3;
#
#   3.4     2016-12-22	Allow e.g. "24.12" as begin or end date. Or just "24"
#   3.3     2004-06-14	Converted everything to UTF8
#   3.2     2004-06-14	UTF8 Fix
#   3.1     2003-04-09	Fixed day overflow in report with overtime < 24 h
#   3.0     2002-11-20	Now the daterange can be given by weeknumber
#   2.94    2002-01-23	Changed output from Day::HH::MM to HH:MM
#   2.93    2002-01-02	Fixed little bug in call to DayOfWeek
#   2.92    2001-12-29	Replaced Functions from Date::Calc
#   2.91    2001-12-28	started removing Date::Calc, due to problems
#			with subtracting times at Freizeitausgleich
#			New: time2daytime
#   2.9	    2001-12-11	Moved data files to $HOME
#   2.8	    2001-12-06	Fixed bug in grep
#   2.7	    2001-12-05	Test if $EDITOR is set and files exist 
#   2.6	    2001-12-05	Adding of comments works now
#
#   2.05    2001-10-24	comment with -c
#   2.04    2001-07-01  Remaining vacation
#   2.03    2001-06-14	-x to mark overtime
#   2.02    2000-12-04	report is its own function now
#   2.01    2000-12-01	rewrite of analyze
#   1.02    2000-11-28	Getopt::Long, introduced #Urlaub and #Freizeitausgleich
#   1.01    2000-11-27	-f reads a file
#   1.00    2000-10-04	first version
#   
#	
# Requested Features:
#   - kostenstellen
#   - alias for comments
#
# Dataformats:
#
# Time	    Seconds (signed integer)
# Daytime   String "[DAYSd ]hh:mm:ss"
# Day	    String "Day:MONTH:YEAR"   (German date format)
# Day	    String "YYYYMMDD"   (STTS date format)
#
# Todo:
# - Replace old timeformats by the new ones (above)  see ### xxx
# - Remove/rewrite
#   *	Use of Date::Calc functions
# - check, if Freizeitausgleich calculation is correct now
#   .tmdata is already converted now.

#use strict;

use Date::Calc qw (:all);  # xxx

use Getopt::Long;
GetOptions (
    "b=s"=> \$opt_begin,
    "c=s"=> \$opt_comment,
    "e=s"=> \$opt_end,
    "d!" => \$opt_debug,
    "f=s" => \$opt_file,
    "g=s"=> \$opt_grep,
    "h!" => \$opt_usage,
    "i!" => \$opt_enter,
    "o!" => \$opt_leave,
    "l!" => \$opt_lesson,
    "s!" => \$opt_sze,
    "t!" => \$opt_today,
    "v!" => \$opt_edit,
    "w=s"=> \$opt_week,
    "x!" => \$opt_x ) || usage ();

# Momentanes Datum und Zeit
$Yn=`date +%Y`; chop ($Yn);
$Mn=`date +%m`; chop ($Mn);
$Dn=`date +%d`; chop ($Dn);
$hn=`date +%k`; chop ($hn);
$mn=`date +%M`; chop ($mn);
$sn=`date +%S`; chop ($sn);

# Global variables
my ($Db,$Mb,$Yb,$De,$Me,$Ye);	# Begin and end of daterange
my ($working);		# work in progress...?
my ($Ds,$hs,$ms,$ss);	# Sum of working time
my ($Yl,$Ml,$Dl);	# last date
my ($work);		# number working days
my ($urlaub);		# number of vacation days
my ($freizeit);		# number of days with "Freizeitausgleich"

# Filenames

my ($DATAFILE)="$ENV{'HOME'}/.tmdata";
my ($COMMFILE)="$ENV{'HOME'}/.tmcomment";

if ($opt_edit)	{ edit  ($DATAFILE); }

if ($opt_usage) {
    $0 =~ s#.*/##g;
    print <<Helpende;
    
Timemachine written by Uwe Drechsel - Version $version

usage: $0 [-h][-f filenames][comment]
  -h     help
  -f     Filename
  -g     grep befory generating a report e.g. grep for a comment
  -i     in      
  -o     out     
  -c     comment and new login (comment is added after loggin out) 
  -x     extra worktime (doesn't count as regular workday and is marked with  *)
  -l     Lesson English (ends session with §Lesson English§)
  -b     Begin Daterange (format DD or DD.MM or DD.MM.YYYY. default: today)
  -e     Ende Daterange  (format DD or DD.MM or DD.MM.YYYY. default: today)
  -s     SZE-entries 
  -t     worktime today 
  -v     open data in \$EDITOR (or in vi)
  -w     week (sets range for the week of the actual year)
  -d     Debug Mode


Installation:
    Please install /suse/perl2/perl-Date-Calc.rpm
    and touch the DATAFILE, e.g.
    touch $DATAFILE

Files:
    Timemachine uses two files: DATAFILE and COMMFILE. 
    DATAFILE=$DATAFILE

    is used to store the information about logins, logouts, comments. 
    Before the first use of timemachine you should create it by
    touch $DATAFILE

    In this file you have:
      * 
	extra worktime (doesn't count as regular workday and 
	is marked with  *)
    §+time§ and §-time§  
	are added/subtracted from the worktime
    §Urlaub--§  and §Urlaub+=123§  
	modify the vacation days 
    §Freizeitausgleich§ 
	increases the days for "Freizeitausgleich" and starts 
	a new workday
    "this is not important" 
	is ignored by timemachine, but can be used to grep for
	certain lines with the -g option


    COMMFILE=$COMMFILE

    is used to save the comment for writing it later to DATAFILE
Helpende

exit;
}


# Set Range. Default 26.1.1970-today
if ($opt_week) {
    ($Yb,$Mb,$Db)=Monday_of_Week($opt_week,$Yn);
    ($Ye,$Me,$De)=Add_Delta_Days($Yb,$Mb,$Db,6);
    #print "Week $opt_week:  $Db.$Mb.$Yb - $De.$Me.$Ye\n";
} else {
    # Don't use -b and -e if -w is used...
    if ($opt_begin) {
        ($Db, $Mb, $Yb) = smartDate ($opt_begin);
    } else {
        $Db=26;$Mb=1,$Yb=1970;
    }
    print "db=$Db  mb=$Mb  yb=$Yb\n";

    if ($opt_end) {
        ($De, $Me, $Ye) = smartDate ($opt_end);
    } elsif ($opt_today)  
	{$Db=$Dn;$Mb=$Mn,$Yb=$Yn; $De=$Dn;$Me=$Mn,$Ye=$Yn;}
    else
	{$De=$Dn;$Me=$Mn,$Ye=$Yn;}
}	

# Work on  given file or default-file
if ($opt_file) {
    $DATAFILE=$opt_file;
}
    
analyze($Db,$Mb,$Yb,$De,$Me,$Ye);
if ($opt_lesson){ 
    if ($working) {
	# in: leave first
	leave ($DATAFILE);
    }	
    open (AFH,">>$DATAFILE") or die "Couldn't open $DATAFILE!\n";
    $out=DayOfWeek("$Dn.$Mn.$Yn");
    $out=$out . sprintf (" %02i.%02i.%04i",$Dn,$Mn,$Yn);
    $out = $out . " §Englisch§\n";
    print AFH $out;
    close (AFH) or die "Error while closing $DATAFILE!\n";
    $opt_enter="";
    $opt_leave="";
    $opt_comment="";
}

if ($opt_enter) { enter ($DATAFILE); }
if ($opt_leave) { leave ($DATAFILE); }

# Write comment if there are arguments left
if ($#ARGV>=0) { $opt_comment=$ARGV[0]; }

# Write comment if -c option is given
if ($opt_comment) {
    if ($working) {
	leave ($DATAFILE);
    }	
    open (AFH,,">$COMMFILE") or die "Couldn't open $COMMFILE!\n";
    print AFH $opt_comment;
    close (AFH) or die "Error while closing $COMMFILE!\n";
    enter ($DATAFILE);	
} elsif ($opt_enter) {
    system ("rm -f $COMMFILE");
}

report();

exit;

########################################################
sub kurzarbeit{		    # Ist Datum in KA-Zeitraum?
########################################################
    my ($D0,$M0,$Y0)=@_;
	return daterange (1,3,2009,$D0,$M0,$Y0,31,10,2009);
}

########################################################
sub DayOfWeek {	    # locale's abbreviated weekday name
########################################################
    # see also for Date::Calc 
    # Day_of_Week_Abbreviation (Day_of_Week($Y,$M,$D)
    my ($date)=$_[0];
    $date=~/([0-9]+)\.([0-9]+)\.([0-9]+)/;
    $date= `date -d \"$3-$2-$1\" +%a`;
    chop ($date);
    return $date;
}   

########################################################
sub smartDate {  # allow e.g. 24.12. or just 24 for date
########################################################
    my ($date) = @_;
    my @a;

    $date =~ /\s*([0-9]+)/;
    $a[0] = defined($1) ?  $1: $Dn;

    $date =~ /\s*([0-9]+)\.([0-9]+)/;
    $a[1] = defined($2) ?  $2: $Mn;

    $date =~ /\s*([0-9]+)\.([0-9]+)\.([0-9]+)/;
    $a[2] = defined($3) ?  $3: $Yn;

    return @a;
}

########################################################
sub tstring {			    # time to string
### xxx
########################################################
    my ($s);
    $D=$_[0];
    $M=$_[1];
    $Y=$_[2];
    $h=$_[3];
    $m=$_[4];
    $S=$_[5];
    $s=DayOfWeek("$D.$M.$Y");
    $s="$s $D.$M.$Y $h:$m:$S";
    return $s;
}

########################################################
sub time2text {			# Zeit h,m,s -> String
### xxx
########################################################
    my ($h,$m,$s)=@_;
    return sprintf( "%02i:%02i:%02i",$h,$m,$s);
}

########################################################
sub time2shorttext {		# Zeit h,m -> String
### xxx
########################################################
    my ($h,$m)=@_;
    return sprintf( "%02i:%02i",$h,$m);
}

########################################################
sub timeint2text {	# Zeitintervall D,h,m,s -> String
### xxx
########################################################
    my ($D,$h,$m,$s,$sign)=@_;
    my ($vz)=" ";	    # falls nur 4 Parameter: vz=" "
    if ( defined $sign) {   # sonst evtl. vz="-" oder " "
	if ($sign<0) 
	    {$vz="-";}
    }
    return $vz . sprintf( "%02id %02i:%02i:%02i",$D,$h,$m,$s);
}

########################################################
sub timeint2shorttext {	    # Zeitintervall D,h,m -> String
### xxx
########################################################
    my ($D,$h,$m,$s,$sign)=@_;
    my ($vz)=" ";	    # falls nur 4 Parameter: vz=" "
    if ( defined $sign) {   # sonst evtl. vz="-" oder " "
	if ($sign<0) 
	    {$vz="-";}
    }
    return $vz . sprintf( "%02id %02i:%02i",$D,$h,$m);
}

########################################################
sub date2text {		    # Datum D,M,Y  -> String
### xxx
########################################################
    my ($D,$M,$Y)=@_;
    return sprintf( "%02i.%02i.%04i",$D,$M,$Y);
}


########################################################
sub before_date {		# Date 0 <= date 1 ?
### xxx
########################################################
    my ($D0,$M0,$Y0,$D1,$M1,$Y1)=@_;
    return 0 if ($Y0>$Y1);
    return 1 if ($Y0<$Y1);
    return 0 if ($M0>$M1);
    return 1 if ($M0<$M1);
    return 0 if ($D0>$D1);
    return 1;
}

########################################################
sub daterange {		    # Date 1 in Range 0-2?
### xxx
########################################################
    my ($D0,$M0,$Y0,$D1,$M1,$Y1,$D2,$M2,$Y2)=@_;
    return 1 if (   (before_date($D0,$M0,$Y0, $D1,$M1,$Y1) ) &&
		    (before_date($D1,$M1,$Y1, $D2,$M2,$Y2) ) );
    return 0;
}


########################################################
sub add_time {	# Zeit addieren D,h,m,s,Dd,hd,md,sd
### xxx
########################################################
    my ($D,$h,$m,$s,$Dd,$hd,$md,$sd)=@_;
    use integer;
    $s=$s+$sd; if ($s>59) {$m=$m+$s/60; $s=$s % 60;}
    $m=$m+$md; if ($m>59) {$h=$h+$m/60; $m=$m % 60;}
    $h=$h+$hd; if ($h>23) {$D=$D+$h/24; $h=$h % 24;}
    $D=$D+$Dd;
    return ($D,$h,$m,$s);
    no integer;
}

########################################################
sub sub_time {	# Zeit subtrahieren D0,h0,m0,s0,D1,h1,m1,s1
### xxx
########################################################
    my ($D0,$h0,$m0,$s0,$D1,$h1,$m1,$s1)=@_;
    my ($sign)=1;
    use integer;
    #erstmal in s umwandeln
    my ($sek0,$sek1, $Dd,$hd,$md,$sd);
    $sek0=$D0*24*3600 + $h0*3600 +$m0*60 +$s0;
    $sek1=$D1*24*3600 + $h1*3600 +$m1*60 +$s1;

    if ($sek1>$sek0) {	# negatives Vorzeichen
	$sign=$sek1;
	$sek1=$sek0;
	$sek0=$sign;
	$sign=-1;
    }
    #Differenz berechnen
    $sd=$sek0-$sek1;
    $Dd=$sd / 86400;	# Anzahl s pro Tag
    $sd=$sd % 86400;

    $hd=$sd / 3600;
    $sd=$sd % 3600;

    $md=$sd / 60;
    $sd=$sd % 60;
    return ($Dd,$hd,$md,$sd,$sign);
    no integer;
}

########################################################
sub time2daytime {	    # seconds to daytime format  
########################################################
    my ($s)=@_;
    my ($Dd,$hd,$md,$sd);
    my ($sign)=1;
    use integer;

    $sign=-1 if $s <0;

    $Dd=$s / 86400; # Anzahl s pro Tag
    $sd=$s % 86400;

    $hd=$s / 3600;
    $sd=$s % 3600;

    $md=$s / 60;
    $sd=$s % 60;

    return ($Dd,$hd,$md,$sd,$sign);
    no integer;
}

########################################################
sub analyze{			    # FILE auswerten
########################################################
    my (@lines)=readfile($DATAFILE);	# File mit Zeitangaben
    my ($Yb,$Mb,$Db);		    # Beginn Zeitraum
    $Db=$_[0];
    $Mb=$_[1];
    $Yb=$_[2];
    my ($Ye,$Me,$De);		    # Ende   Zeitraum
    $De=$_[3];
    $Me=$_[4];
    $Ye=$_[5];
    my ($Y0,$M0,$D0,$h0,$m0,$s0);   # Anfangszeit in Zeile
    my ($Y1,$M1,$D1,$h1,$m1,$s1);   # Endzeit in Zeile     
    my (        $Dd,$hd,$md,$sd);   # Differenzeit in Zeile
    my (        $Dt,$ht,$mt,$st);   # Summe pro Tag
    ($Ds,$hs,$ms,$ss)=(0,0,0,0);
    ($Dt,$ht,$mt,$st)=(0,0,0,0);
    ($Dd,$hd,$md,$sd)=(0,0,0,0);
    ($Yl,$Ml,$Dl)=(0,0,0);	
    $work=0;			# reguläre arbeitstage
    $work_ka=0;			# arbeitstage in KA
    $urlaub=0;
    $freizeit=0;
    $working=0;

    my $s;			    # Suchstring

    if ($opt_grep) {		    # grep before analyzing
	@new=grep {/$opt_grep/} @lines;
	@lines=@new;
    }
    
    foreach (@lines) {
	$xworking=0;
	if (/[0-9]/) {	# ignore lines without numbers
	    # Read date
	    /([0-9]+)\.([0-9]+)\.([0-9]+)/;
	    $D0=$1; $M0=$2; $Y0=$3; 
	    if (daterange ($Db,$Mb,$Yb, $D0,$M0,$Y0, $De,$Me,$Ye)) {
		if ($opt_grep) {
		    # Show lines if grep is used, just to be sure
		    print "$_";
		}

	    # Do we have a new day?
	    if ( ($Dl!=$D0) || ($Ml!=$M0) || ($Yl!=$Y0)) {
		if (!/\*/) {
			if (kurzarbeit ($D0,$M0,$Y0))
			{
				$work_ka++;
			} else
			{
				$work++;
			}
		    if ($opt_sze && $Dl!=0) {
			print "mysze $Dl.$Ml.$Yl  $ht:$mt \n";
		    }
		    $Dl=$D0; $Ml=$M0; $Yl=$Y0;	
		    ($Dt,$ht,$mt,$st)=(0,0,0,0);
		} else {
		    $xworking=0;
		}
	    }	

		if (/§/) {
		    /§(.+)§/;
		    $s=$1;
		    if ($s=~/Urlaub--/) {$urlaub--;}
		    if ($s=~/Urlaub\+=([0-9]+)/) {$urlaub=$urlaub+$1;}
		    if ($s=~/Freizeitausgleich/) {$freizeit++;}
		    if ($s=~/\+([0-9]+):([0-9]+):([0-9]+)/) {
			($Ds,$hs,$ms,$ss)=add_time 
					($Ds,$hs,$ms,$ss, 0,$1,$2,$3);
		    }
		    if ($s=~/-([0-9]+):([0-9]+):([0-9]+)/) {
			($Ds,$hs,$ms,$ss)=sub_time 
					($Ds,$hs,$ms,$ss, 0,$1,$2,$3);
		    }
		} # End of � 
		else {
		    # Anfangszeit auslesen (Datum ist schon da)
		    /([0-9]+):([0-9]+):([0-9]+)/;
		    $h0=$1;$m0=$2;$s0=$3;
		    # Endzeit auslesen bzw. auf aktuelle Zeit setzen
		    if (/>/) {
			/>([0-9]+):([0-9]+):([0-9]+)/;
			$D1=$D0;$M1=$M0;$Y1=$Y0; $h1=$1;$m1=$2;$s1=$3;
			$working =0;
		    }	
		    else { 
			($Y1,$M1,$D1,$h1,$m1,$s1) = ($Yn,$Mn,$Dn,$hn,$mn,$sn); 
			$working=1;
		    }
	    
		    # Differenz Anfang->Ende ausrechnen
#		    ($Dd,$hd,$md,$sd)=Delta_DHMS($Y0,$M0,$D0,$h0,$m0,$s0,
#						$Y1,$M1,$D1,$h1,$m1,$s1);
		    ($Dd,$hd,$md,$sd)=sub_time ($D0,$h0,$m0,$s0,
						$D1,$h1,$m1,$s1);
	    
		    # Summe  ausrechnen
		    ($Ds,$hs,$ms,$ss)=add_time($Ds,$hs,$ms,$ss,  
						$Dd,$hd,$md,$sd);
		    ($Dt,$ht,$mt,$st)=add_time($Dt,$ht,$mt,$st,
						$Dd,$hd,$md,$sd);
		} # End of no �
		debug ("Day $Y0-$M0-$D0 workdays: $work (KA: $work_ka) Sum today: $ht:$mt Diff: d=$Dd d $hd:$md:$sd  Sum total= $Ds d $hs:$ms:$ss");
	    } # End of in daterange
	} # End of line containing a number
    } # End of @lines
} # analyze

########################################################
sub report{			    # Report generieren
########################################################
    my $c;  # used for showing the comment
    my @a;  # used for showing the comment
    if (-f $COMMFILE) { 
	@a=readfile ($COMMFILE);
	$c="\"" . $a[0] . "\"";
    } else {
	$c="";	# empty string to avoid error at concatenation
    }

    print  "\n";
    print  "Report ",
	date2text($Db,$Mb,$Yb),"-",
	date2text($De,$Me,$Ye),"      ", 
	time2text($hn,$mn,$sn),"\n";
    print  "==========================================\n";
    printf "       Arbeitstage: %4d \n",$work;
    printf "  Kurz-Arbeitstage: %4d \n",$work_ka;
    printf "        Resturlaub: %4d \n",$urlaub;
    printf " Freizeitausgleich: %4d \n",$freizeit;

    printf "      Summe bisher: %4d:%02d \n",$Ds*24+$hs,$ms;

    # @over is needed until I changed the time format completly:      
    my @over=sub_time (	$Ds,$hs,$ms,$ss,0,8*($work) + 7*$work_ka,0,0,0);  

	if ($over[4]<0) {
	    printf "       Überstunden:   -%2d:%02d\n",($over[1]+24*$over[0]),$over[2];
	} else {
	    printf "       Überstunden:  %4d:%02d\n",($over[1]+24*$over[0]),$over[2];
	}
    print  "           Comment: $c\n",
	   "            Status: ";
    if (!$working) {
	print "out\n";
    } else {
	if (!$working) {
	    print "in (Kein Werktag) \n";
	} else {
	    print "in \n";
	}
    }	
	
} # report

########################################################
sub readfile {                      # Read file
########################################################
    my ($filename) =@_;
    my (@lines);
    open (INFILE, "<$filename") ||
    die "Datei $filename nicht lesbar";
    @lines=<INFILE>;
    return @lines;
}

########################################################
sub debug {
########################################################
    if ($opt_debug) {
        print "Debug: @_\n";
    }
}
  

########################################################
sub edit {				# Edit datafile
########################################################
    my ($filename) =@_;
    if (defined $ENV{'EDITOR'}) {
	system ("$ENV{'EDITOR'} $filename");
    } else {
	system ("export LANG=C;vi $filename");
    }
}

########################################################
sub enter {				# Anfang Arbeit
########################################################
    my $out;

    # Kein Autobuild während meiner Arbeitszeit
    system ("touch /tmp/noautobuild");
    print "I have touched /tmp/noautobuild for your convenience!\n";

    if ($working) 
	{print "\nDu bist bereits am arbeiten?!\n\n";}
    else {
	my ($out);
	my ($FILENAME)=@_;
	open (AFH,">>$FILENAME") or die "Couldn't open $FILENAME!\n";
	$out=DayOfWeek("$Dn.$Mn.$Yn");
	$out=$out . sprintf (" %02i.%02i.%04i",$Dn,$Mn,$Yn);
	if ($opt_x) {
	    $out=$out . "*";   # Kein Werktag!
	} else {
	    $out=$out . " ";
	}
	if ($opt_lesson) { $out = $out . "§Englisch§\n".$out;}
	$out=$out . sprintf ("%02i:%02i:%02i",$hn,$mn,$sn);
	print AFH "$out-";
	close (AFH) or die "Error while closing $FILENAME!\n";
	$working=1;
    }
}

########################################################
sub leave {				# Ende  Arbeit
########################################################
    my $out;
    my @s;

    if (!$working) 
	{print "\nDu bist gar nicht am arbeiten?!\n\n";}
    else {
	my ($out);
	my ($FILENAME)=@_;
	open (AFH,">>$FILENAME") or die "Couldn't open $FILENAME!\n";
	$out=">" . sprintf ("%02i:%02i:%02i",$hn,$mn,$sn);

	# Falls Kommentar vorhanden, diesen anh�ngen
	if (-f $COMMFILE) {
	    @s=readfile ($COMMFILE);
	    $out=$out . " \"" . $s[0] . "\"";
	}
	print AFH "$out\n";
	close (AFH) or die "Error while closing $FILENAME!\n";
	$working=0;
    }	
}
