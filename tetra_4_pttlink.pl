#!/usr/bin/perl
#
#

# sudo cpan install Switch Config::IniFiles Device::SerialPort IO::Socket::Timeout IO::Socket::Multicast JSON Ham::APRS::IS Term::ReadKey
# sudo apt-get install git-core
# sudo git clone https://github.com/WiringPi/WiringPi.git /opt/wiringpi
# cd /opt/wiringpi
# sudo ./build
# sudo cpan install RPi::Pin RPi::Const



# Strict and warnings recommended.
use strict;
use warnings;
use IO::Select;
use Switch;
use Config::IniFiles;
use Device::SerialPort;
use IO::Socket;
use IO::Socket::INET;
use IO::Socket::Timeout;
use IO::Socket::Multicast;
use JSON;
use Data::Dumper qw(Dumper);
use Time::HiRes qw(nanosleep);

use Sys::Hostname;

use RPi::Pin;
use RPi::Const qw(:all);

use Ham::APRS::IS;
use Term::ReadKey;
use Term::ANSIColor;

use Class::Struct;

# Needed for FAP:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
use TetraLogic;
use TetraLib;
use PTTLink;
# Use custom version of FAP:
use FAP;


my $MaxLen =1024; # Max Socket Buffer length.
my $StartTime = time();



# About this app.
my $AppName = 'TETRA 4 PTTLink';
use constant VersionInfo => 1;
use constant MinorVersionInfo => 00;
use constant RevisionInfo => 0;
my $Version = VersionInfo . '.' . MinorVersionInfo . '-' . RevisionInfo;
print color('green'), "\n##################################################################\n";
print "	*** $AppName v$Version ***\n";
print "	Released: March 12, 2022. Created March 01, 2022.\n";
print "	Created by:\n";
print "	Juan Carlos Pérez De Castro (Wodie) KM4NNO / XE1F\n";
print "	www.wodielite.com\n";
print "	wodielite at mac.com\n";
print "	km4nno at yahoo.com\n\n";
print "	License:\n";
print "	This software is licenced under the GPL v3.\n";
print "	If you are using it, please let me know, I will be glad to know it.\n\n";
print "	This project is based on the work and information from:\n";
print "	Juan Carlos Pérez KM4NNO / XE1F\n";
print "	APRS is a registed trademark and creation of Bob Bruninga WB4APR\n";
print "\n##################################################################\n\n", color('reset');

# Detect Target OS.
my $OS = $^O;
print color('green'), "Current OS is $OS\n", color('reset');

# Load Settings ini file.
print color('green'), "Loading Settings...\n", color('reset');
my $cfg = Config::IniFiles->new( -file => "config.ini");
# Settings:
my $Mode = $cfg->val('Settings', 'HardwareMode'); #0 = v.24, no other modes coded at the momment.
my $HotKeys = $cfg->val('Settings', 'HotKeys');
my $Node_Number = $cfg->val('Settings', 'Node_Number');
my $Callsign = $cfg->val('Settings', 'Callsign');
my $SiteName = $cfg->val('Settings', 'SiteName');
my $SiteInfo = $cfg->val('Settings', 'SiteInfo');
my $Verbose = $cfg->val('Settings', 'Verbose');
print "	Mode = $Mode\n";
print "	HotKeys = $HotKeys\n";
print "	Node_Number = $Node_Number\n";
print "	Callsign = $Callsign\n";
print "	SiteName = $SiteName\n";
print "	SiteInfo = $SiteInfo\n";
print "	Verbose = $Verbose\n";
print "----------------------------------------------------------------------\n";



# TETRA Init.
print color('green'), "Init TETRA.\n", color('reset');
my $SerialPort = TetraLogic->new(
	'debug' => 3,
);
print "----------------------------------------------------------------------\n";



# APRS-IS:
print color('green'), "Loading APRS-IS...\n", color('reset');
my $APRS_Passcode = $cfg->val('APRS', 'Passcode');
my $APRS_Suffix = $cfg->val('APRS', 'Suffix');
my $APRS_Server= $cfg->val('APRS', 'Server');
my $APRS_File = $cfg->val('APRS', 'APRS_File');
my $APRS_Interval = $cfg->val('APRS', 'APRS_Interval') * 60;
my $My_Latitude = $cfg->val('APRS', 'Latitude');
my $My_Longitude = $cfg->val('APRS', 'Longitude');
my $My_Symbol = $cfg->val('APRS', 'Symbol');
my $My_Altitude = $cfg->val('APRS', 'Altitude');
my $My_Freq = $cfg->val('APRS', 'Frequency');
my $My_Tone = $cfg->val('APRS', 'AccessTone');
my $My_Offset = $cfg->val('APRS', 'Offset');
my $My_NAC = $cfg->val('APRS', 'NAC');
my $My_Comment = $cfg->val('APRS', 'APRSComment');
my $APRS_Verbose= $cfg->val('APRS', 'Verbose');
print "	Passcode = $APRS_Passcode\n";
print "	Suffix = $APRS_Suffix\n";
print "	Server = $APRS_Server\n";
print "	APRS File $APRS_File\n";
print "	APRS Interval $APRS_Interval\n";
print "	Latitude = $My_Latitude\n";
print "	Longitude = $My_Longitude\n";
print "	Symbol = $My_Symbol\n";
print "	Altitude = $My_Altitude\n";
print "	Freq = $My_Freq\n";
print "	Tone = $My_Tone\n";
print "	Offset = $My_Offset\n";
print "	NAC = $My_NAC\n";
print "	Comment = $My_Comment\n";
print "	Verbose = $APRS_Verbose\n";
my $APRS_IS;
my %APRS;
my $APRS_NextTimer = time();
if ($APRS_Passcode ne Ham::APRS::IS::aprspass($Callsign)) {
	$APRS_Server = undef;
	warn color('red'), "APRS invalid pasword.\n", color('reset');
}
my $APRS_Callsign = $Callsign . '-' . $APRS_Suffix;
print "	APRS Callsign = $APRS_Callsign\n";
if (defined $APRS_Server) {
	$APRS_IS = new Ham::APRS::IS($APRS_Server, $APRS_Callsign,
		'appid' => "$AppName $Version",
		'passcode' => $APRS_Passcode,
		'filter' => 't/m');
	if (!$APRS_IS) {
		warn color('red'), "Failed to create APRS-IS Server object: " . $APRS_IS->{'error'} .
			"\n", color('reset');
	}
	#Ham::APRS::FAP::debug(1);
}
print "----------------------------------------------------------------------\n";



# Raspberry Pi GPIO
print color('green'), "Init GPIO\n", color('reset');
my $PTT_IN_GPIO = $cfg->val('GPIO', 'PTT_IN_GPIO'); # Red
my $SQL_OUT_GPIO = $cfg->val('GPIO', 'SQL_OUT_GPIO'); # Yellow
my $AUX_IN_GPIO = $cfg->val('GPIO', 'AUX_IN_GPIO');
my $PTT_2_OUT_GPIO = $cfg->val('GPIO', 'PTT_2_OUT_GPIO');
my $SQL_2_IN_GPIO = $cfg->val('GPIO', 'SQL_2_IN_GPIO');
print "	PTT_IN_GPIO = $PTT_IN_GPIO\n";
print "	SQL_OUT_GPIO = $SQL_OUT_GPIO\n";
print "	AUX_IN_GPIO = $AUX_IN_GPIO\n";
print "	PTT_2OUT_GPIO = $PTT_2_OUT_GPIO\n";
print "	SQL_2_IN_GPIO = $SQL_2_IN_GPIO\n";
print "	GPIO_Verbose = $Verbose\n";

my $PTT_IN_PIN = RPi::Pin->new($PTT_IN_GPIO, "Red");
my $SQL_OUT_PIN = RPi::Pin->new($SQL_OUT_GPIO, "Yellow");
my $AUX_IN_PIN = RPi::Pin->new($AUX_IN_GPIO);
my $PTT_2_OUT_PIN = RPi::Pin->new($PTT_2_OUT_GPIO);
my $SQL_2_IN_PIN = RPi::Pin->new($SQL_2_IN_GPIO);

# This use the BCM pin numbering scheme.
# Valid GPIOs are: 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27.
# GPIO 2, 3 Aleternate for I2C.
# GPIO 14, 15 alternate for USART.
$PTT_IN_PIN->mode(INPUT); # Red
$SQL_OUT_PIN->mode(OUTPUT); # Yellow
$AUX_IN_PIN->mode(OUTPUT);
$PTT_2_OUT_PIN->mode(OUTPUT);
$SQL_2_IN_PIN->mode(INPUT);

$SQL_OUT_PIN->write(HIGH); # Yellow
$PTT_2_OUT_PIN->write(HIGH);

$PTT_IN_PIN->pull(PUD_UP); # Red
$AUX_IN_PIN->pull(PUD_UP);
$SQL_2_IN_PIN->pull(PUD_UP);

my $PTT_in_old = 0;
my $AUX_in_old = 0;
my $PTT_2_out_old = 0;
my $SQL_2_in_old = 0;

#$PTT_IN_PIN->set_interrupt(EDGE_BOTH, 'main::PTT_IN_PIN_Interrupt_Handler'); # Red
#$AUX_IN_PIN->set_interrupt(EDGE_BOTH, 'main::AUX_IN_PIN_Interrupt_Handler');
#$SQL_2_IN_PIN->set_interrupt(EDGE_BOTH, 'main::SQL_2_IN_PIN_Interrupt_Handler');
print "----------------------------------------------------------------------\n";



# Read Keys:
if ($HotKeys) {
	ReadMode 3;
	PrintMenu();
}
print "----------------------------------------------------------------------\n";



# Misc
my $Read_Timeout = 0.003;
my $Run = 1;

my $LinkedTalkGroup = 0;



###################################################################
# MAIN ############################################################
###################################################################
if ($Mode == 1) { # If Cisco STUN (Mode 1) is selected:
	while ($Run) {
		MainLoop();
	}
} else { # If Serial (Mode 0) is selected: 
	while ($Run) {
		MainLoop();
	}
}
# Program exit:
print "----------------------------------------------------------------------\n";
ReadMode 0; # Set keys back to normal State.
if ($Mode == 0) { # Close Serial Port:
	$SerialPort->close || die "Failed to close SerialPort.\n";
}
if ($APRS_IS and $APRS_IS->connected()) {
	$APRS_IS->disconnect();
	print color('yellow'), "APRS-IS Disconected.\n", color('reset');
}
print "Good bye cruel World.\n";
print "----------------------------------------------------------------------\n\n";
exit;



##################################################################
# Menu ###########################################################
##################################################################
sub PrintMenu {
	print "----------------------------------------------------------------------\n";
	print "Shortcuts menu:\n";
	print "  Q/q = Quit.                      h = Help...                     \n";
	print "  A/a = APRS  show/hide verbose.   C/c =                           \n";
	print "  E/e = Emergency Page/Alarm.      F/f = Serach user test.         \n";
	print "  A/a = APRS  show/hide verbose.   H/h = Help                      \n";
	print "  J/j = JSON  show/hide verbose.   M/m =                           \n";
	print "  P/p =                            L/l =                           \n";
	print "  S/s =                            T/t = Test.                   \n\n";
	print "----------------------------------------------------------------------\n";
}



##################################################################
# APRS-IS ########################################################
##################################################################
sub APRS_connect {
	my $Ret = $APRS_IS->connect('retryuntil' => 2);
	if (!$Ret) {
		warn color('red'), "Failed to connect APRS-IS server: " . $APRS_IS->{'error'} . "\n", color('reset');
		return;
	}
	print "	APRS-IS: connected.\n";
}

sub APRS_Timer { # APRS-IS
	if (time() >= $APRS_NextTimer) {
		if ($APRS_IS) {
			if (!$APRS_IS->connected()) {
				APRS_connect();
			}
			if ( $APRS_IS->connected() ) {
				if ($APRS_Verbose) {print color('green'), "APRS-IS Timer.\n", color('reset');}
				APRS_Update($LinkedTalkGroup);
			}
		}
		$APRS_NextTimer = time() + $APRS_Interval;
	}
}

sub APRS_Make_Pos {
	my ($Call, $Latitude, $Longitude, $Speed, $Course, $Altitude, $Symbol, $Comment) = @_;
	if (!$APRS_IS) {
		warn color('red'), "	APRS-IS does not exist.\n", color('reset'); 
		return;
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "	APRS-IS not connected, trying to reconnect.\n", color('reset'); 
		APRS_connect();
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "APRS-IS can not connect.\n", color('reset'); 
		return;
	}
	my %Options;
	$Options{'timestamp'} = 0;
	$Options{'comment'} = 'Hola';
	
	my $APRS_position = Ham::APRS::FAP::make_position(
		$Latitude,
		$Longitude,
		$Speed, # speed
		$Course, # course
		$Altitude, # altitude
		(defined $Symbol) ? $Symbol : '/[', # symbol
		{
		#'compression' => 1,
		#'ambiguity' => 1, # still can not make it work.
		#'timestamp' => time(), # still can not make it work.
		'comment' => $Comment,
		#'dao' => 1
	});
	if ($APRS_Verbose > 1) {print color('green'), "	APRS Position is: $APRS_position\n", color('reset');}
	my $Packet = sprintf('%s>APTR01:%s', $Call, $APRS_position . $Comment);
	print color('blue'), "	$Packet\n", color('reset');
	if ($APRS_Verbose > 2) {print "	APRS Packet is: $Packet\n";}
	my $Res = $APRS_IS->sendline($Packet);
	if (!$Res) {
		warn color('red'), "Error sending APRS-IS Pos packet $Res\n", color('reset');
		$APRS_IS->disconnect();
		return;
	}
	print color('grey12'),"	APRS_Make_Pos done for $APRS_Callsign\n", color('reset');
}

sub APRS_Make_Object {
	my ($Name, $TimeStamp, $Latitude, $Longitude, $Symbol, $Speed, 
		$Course, $Altitude, $Alive, $UseCompression, $PosAmbiguity, $Comment) = @_;
	if (!$APRS_IS) {
		warn color('red'), "	APRS-IS does not exist.\n", color('reset');
		return;
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "	APRS-IS not connected, trying to reconnect.\n", color('reset'); 
		APRS_connect();
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "APRS-IS can not connect.\n", color('reset'); 
		return;
	}
	
	my $APRS_object = Ham::APRS::FAP::make_object(
		$Name, # Name
		$TimeStamp,
		$Latitude,
		$Longitude,
		$Symbol, # symbol
		$Speed, # speed
		$Course,
		$Altitude, # altitude
		$Alive,
		$UseCompression,
		$PosAmbiguity,
		$Comment
	);
	if ($APRS_Verbose > 0) {print "	APRS Object is: $APRS_object\n";}
	my $Packet = sprintf('%s>APTR01:%s', $APRS_Callsign, $APRS_object);
	print color('blue'), "	$Packet\n", color('reset');
	my $Res = $APRS_IS->sendline($Packet);
	if (!$Res) {
		warn color('red'), "*** Error *** sending APRS-IS Object $Name packet $Res\n", color('reset');
		$APRS_IS->disconnect();
		return;
	}
	if ($APRS_Verbose) { print color('grey12'), "	APRS_Make_Object $Name sent.\n", color('reset'); }
}

sub APRS_Make_Item {
	my ($Name, $Latitude, $Longitude, $Symbol, $Speed, 
		$Course, $Altitude, $Alive, $UseCompression, $PosAmbiguity, $Comment) = @_;
	if (!$APRS_IS) {
		warn color('red'), "	APRS-IS does not exist.\n", color('reset');
		return;
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "	APRS-IS not connected, trying to reconnect.\n", color('reset'); 
		APRS_connect();
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "APRS-IS can not connect.\n", color('reset'); 
		return;
	}
	
	my $APRS_item = Ham::APRS::FAP::make_item(
		$Name, # Name
		$Latitude,
		$Longitude,
		$Symbol, # symbol
		$Speed, # speed
		$Course,
		$Altitude, # altitude
		$Alive,
		$UseCompression,
		$PosAmbiguity,
		$Comment
	);
	if ($APRS_Verbose > 0) {print "	APRS Item is: $APRS_item\n";}
	my $Packet = sprintf('%s>APTR01:%s', $APRS_Callsign, $APRS_item);
	print color('blue'), "	$Packet\n", color('reset');
	my $Res = $APRS_IS->sendline($Packet);
	if (!$Res) {
		warn color('red'), "*** Error *** sending APRS-IS Item $Name packet $Res\n", color('reset');
		$APRS_IS->disconnect();
		return;
	}
	if ($APRS_Verbose) { print color('grey12'), "	APRS_Make_Item $Name sent.\n", color('reset'); }
}

sub APRS_IS_Message($$) {
	my($dst, @words) = @_;
	my $msg = join(' ', @words);

	print color('green'), "APRS_IS_Message\n", color('reset');

	return if (!$APRS_IS);

	my $now = time();
	# Send specific help for incomplete messages.
	if (!defined $dst || $dst eq '' || $msg eq '') {
		#$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Usage: APRS <callsign> <message>');
		return;
	}

	$dst = uc($dst); # Make destination callsign uppercase.
	print "  dst = $dst, msg = $msg\n";

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
	my $MsgID = "$min$sec";

	my $APRS_IS_Message = Ham::APRS::FAP::make_message(
		$dst,
		$msg,
		$MsgID # seq if aknowlegement expected, up to 5 char.
	);
	print "  $APRS_IS_Message\n";

	my $Packet = sprintf('%s>APTR01:%s', $Callsign, $APRS_IS_Message);
	print color('blue'), "  $Packet\n", color('reset');
	my $Res = $APRS_IS->sendline($Packet);

	if (!$Res) {
		print color('red'), "  Error sending APRS-IS message from " .
			"$Callsign to $dst\n", color('reset');
		$APRS_IS->disconnect();
	}
}

sub APRS_Update_TG {
	my ($TG) = @_;
	APRS_Make_Item($Callsign . '/' . $APRS_Suffix, $My_Latitude, $My_Longitude, $My_Symbol, -1, -1, undef,
		1, 0, 0, $My_Freq . 'MHz ' . $My_Tone . ' ' . $My_Offset . ' NAC-' . $My_NAC . ' ' .
		' TG=' . $TG . ' ' . $My_Comment . ' alt ' . $My_Altitude . 'm');
}

sub APRS_Update {
	my ($TG) = @_;
	# Station position as Object
	if ($APRS_Verbose) { print color('green'), "APRS-IS Update:\n", color('reset'); }
	APRS_Make_Object(
		$Callsign . '/' . $APRS_Suffix,
		0,
		$My_Latitude,
		$My_Longitude,
		$My_Symbol,
		-1,
		-1,
		undef,
		1,
		0,
		0,
		$My_Freq . 'MHz ' . $My_Tone . ' ' . $My_Offset . ' NAC-' . $My_NAC . ' ' .
		' TG=' . $TG . ' ' . $My_Comment . ' alt ' . $My_Altitude . 'm');

	# Objects and Items refresh list loading file.
	my $fh;
	if ($APRS_Verbose) { print color('grey12'), "	Loading APRS File...\n", color('reset'); }
	if (!open($fh, "<", $APRS_File)) {
		warn color('red'), "	*** Error ***	 $APRS_File File not found.\n", color('reset');
	} else {
		if ($APRS_Verbose) { print color('grey12'), "	File Ok.\n", color('reset'); }
		my %result;
		while (my $Line = <$fh>) {
			chomp $Line;
			## skip comments and blank lines and optional repeat of title line
			next if $Line =~ /^\#/ || $Line =~ /^\s*$/ || $Line =~ /^\+/;
			#split each line into array
			my @Line = split(/\t+/, $Line);
			my $Index = $Line[0];
			$APRS{$Index}{'Name'} = $Line[0];
			$APRS{$Index}{'Type'} = $Line[1];
			$APRS{$Index}{'Lat'} = $Line[2];
			$APRS{$Index}{'Long'} = $Line[3];
			$APRS{$Index}{'Speed'} = $Line[4];
			$APRS{$Index}{'Course'} = $Line[5];
			if ($Line[6] >= 0) {
				$APRS{$Index}{'Altitude'} = $Line[6];
			} else {
				$APRS{$Index}{'Altitude'} = -1;
			}
			$APRS{$Index}{'Alive'} = $Line[7];
			$APRS{$Index}{'Symbol'} = $Line[8];
			$APRS{$Index}{'Comment'} = $Line[9];
			if ($APRS_Verbose > 1) {
				print "	APRS Index = $Index";
				print ", Name = $APRS{$Index}{'Name'}";
				print ", Type = $APRS{$Index}{'Type'}";
				print ", Lat = $APRS{$Index}{'Lat'}";
				print ", Long = $APRS{$Index}{'Long'}";
				print ", Speed = $APRS{$Index}{'Speed'}";
				print ", Course = $APRS{$Index}{'Course'}";
				print ", Altitude = $APRS{$Index}{'Altitude'}";
				print ", Alive = $APRS{$Index}{'Alive'}";
				print ", Symbol = $APRS{$Index}{'Symbol'}";
				print ", Comment = $APRS{$Index}{'Comment'}";
				print "\n";
			}
			if ($APRS{$Index}{'Type'} eq 'O') {
				APRS_Make_Object(
					$APRS{$Index}{'Name'},
					0, # Timestamp
					$APRS{$Index}{'Lat'},
					$APRS{$Index}{'Long'},
					$APRS{$Index}{'Symbol'},
					$APRS{$Index}{'Speed'},
					$APRS{$Index}{'Course'},
					$APRS{$Index}{'Altitude'},
					$APRS{$Index}{'Alive'},
					0, # Compression 
					0, # Position Ambiguity
					$APRS{$Index}{'Comment'},
				);
			}
			if ($APRS{$Index}{'Type'} eq 'I') {
				APRS_Make_Item(
					$APRS{$Index}{'Name'},
					$APRS{$Index}{'Lat'},
					$APRS{$Index}{'Long'},
					$APRS{$Index}{'Symbol'},
					$APRS{$Index}{'Speed'},
					$APRS{$Index}{'Course'},
					$APRS{$Index}{'Altitude'},
					$APRS{$Index}{'Alive'},
					0, # Compression 
					0, # Position Ambiguity
					$APRS{$Index}{'Comment'},
				);
			}




		}
		close $fh;
		if ($APRS_Verbose > 2) {
			foreach my $key (keys %APRS)
			{
				print color('green'), "	Key field: $key\n";
				foreach my $key2 (keys %{$APRS{$key}})
				{
					print "	- $key2 = $APRS{$key}{$key2}\n";
				}
				print color('reset');
			}
		}
	}
}




























####################################################
sub setSql {
	my ($is_open) = @_;

	$SQL_OUT_PIN->write(!$is_open);
	#GPIO.output($SQL_OUT_PIN, not is_open);

	if ($is_open){
		# Activity
		$ENV{'VAR_SQL'} = 61;
		system("sudo python change_sql.py --sql 1");
#		system("sudo /usr/sbin/asterisk -rx \"help\"");
	} else {
		# No ctivity
		$ENV{'VAR_SQL'} = 60;
		system("sudo python change_sql.py --sql 0");
#		system("sudo /usr/sbin/asterisk -rx \"help\"");
	}
#	system("VAR_SQL = 0");
#	system("/usr/sbin/asterisk -rx \"iax2 show registry\"");

	my $userName =  $ENV{'LOGNAME'}; 
	print "Running as: $userName\n"; 

	my $var =  $ENV{'VAR_SQL'}; 
	print "VAR_SQL = $var\n"; 
}




sub MessageRoute {
	my ($sds_txt) = @_;

	print color('green'), "MessageRoute\n", color('reset');
	print "	sds_txt = " . $sds_txt . "\n";

	# DAPNET
	my $header = lc(substr($sds_txt, 0, 4));
	if ($header eq "dap ") {
		print "Dapnet\n";
		if (TetraLogic::checkIfDapmessage($sds_txt)) {
			print "Dapnet\n";
			return;
		}
	}

	# APRS
	$header = lc(substr($sds_txt, 0, 5));
	if ($header eq "aprs ") {
		print "APRS\n";
		my ($cmd, $destcall, @words) = @$sds_txt;
		my $msg = join(' ', @words);
		if ($Verbose >= TetraLogic::LOGDEBUG) {
			print "To APRS: call = " . $destcall . ", sds message: " . $msg . "\n";
		}
		APRS_Message($destcall, $msg);
	}

	# PTTLink
	$header = lc(substr($sds_txt, 0, 4));
	if ($header eq "ptt ") {
		print "PTTLink\n";
		substr($sds_txt, 0, 4) = ""; # Replace in a string (used here to erase)
		if ($Verbose >= TetraLogic::LOGDEBUG) {
			print "To PTTLink: sds message: $sds_txt \n";
		}
		PTTLink::RptFun($Node_Number, $sds_txt);
	}
}























#################################################################################
# Misc Subs #####################################################################
#################################################################################
sub getTickCount {
	my ($epochSecs, $epochUSecs) = Time::HiRes::gettimeofday();
	#print $Epock secs $epochSecs Epoch usec $epochUSecs.\n";
	my $TickCount = ($epochSecs * 1000 + int($epochUSecs / 1000));
	return $TickCount;
}

sub Bytes_2_HexString {
	my ($Buffer) = @_;
	# Display Rx Hex String.
	#print "TETRA_Rx Buffer:              ";
	for (my $x = 0; $x < length($Buffer); $x++) {
		print sprintf(" %x", ord(substr($Buffer, $x, 1)));
	}
	print "\n";
}

sub HotKeys {
	# Hot Keys.
	if ($HotKeys) {
		if (not defined (my $key = ReadKey(-1))) {
			# No key yet.
		} else {
			switch (ord($key)) {
				case 0x1B { # Escape
					print "EscKey Pressed.\n";
					$Run = 0;
				}

				case ord('A') { # 'A'
					APRS_Update();
					$APRS_NextTimer = time() + $APRS_Interval;
					$APRS_Verbose = 1;
				}
				case ord('a') { # 'a'
					$APRS_Verbose = 0;
				}
				case ord('C') { # 'C'
					PTTLink::RptFun(51467, "*351410");
				}
				case ord('c') {
					PTTLink::RptFun(51467, "*151410");
				}
				case ord('d') { # 'd'
					foreach (sort keys %ENV) { 
						print "$_  =  $ENV{$_}\n"; 
					}
				}
				case ord('E') {
				}
				case ord('e') {
					TetraLogic::handleSdsMsg("0A0B97F4C8DC921AFFE820");
				}
				case ord('f') {
				}
				case ord('H') { # 'H'
					$Verbose = 1;
				}
				case ord('h') { # 'h'
					PrintMenu();
					$Verbose = 0;
				}
				case ord('L') { # 'L'
				}
				case ord('l') { # 'l'
				}
				case ord('M') { # 'M'
				}
				case ord('m') { # 'm'
				}
				case ord('P') { # 'P'
					TetraLogic::transmitterStateChange(1);
				}
				case ord('p') { # 'p'
					TetraLogic::transmitterStateChange(0);
				}
				case ord('Q') { # 'Q'
					$Run = 0;
				}
				case ord('q') { # 'q'
					$Run = 0;
				}
				case ord('S') { # 'S'
				}
				case ord('s') { # 's'
					TETRA_Tx ("AT");
				}
				case ord('T') { # 'T'
					$Verbose = 1;
				}
				case ord('t') { # 't'
					$Verbose = 0;
				}
				case ord('w') { # 'w'
					TetraLogic::handleCnumf("+CNUMF: 6,09011638300023401");
				}
				case 0x41 { # 'UpKey'
					print "UpKey Pressed.\n";
				}
				case 0x42 { # 'DownKey'
					print "DownKey Pressed.\n";
				}
				case 0x43 { # 'RightKey'
					print "RightKey Pressed.\n";
				}
				case 0x44 { # 'LeftKey'
					print "LeftKey Pressed.\n";
				}
				case '[' { # '['
					print "[ Pressed (used also as an escape char).\n";
				}
				else {
					if ($Verbose) {
						print sprintf(" %x", ord($key));
						print " Key Pressed\n";
					}
				}
			}
		}
	}
}

sub getEnvVars {
#	my $var = $ENV{'VAR_PTT'};
#	print "VAR_PTT = $var\n";

#	my $var = $ENV{'VAR_SQL'};
#	print "VAR_SQL = $var\n";

}

sub GPIOs {
	my $PTT_in = $PTT_IN_PIN->read();
	my $AUX_in = $AUX_IN_PIN->read();
	my $PTT_2_out = $PTT_2_OUT_PIN->read();
	my $SQL_2_in = $SQL_2_IN_PIN->read();

	if ($PTT_in != $PTT_in_old) {
		$PTT_in_old = $PTT_in;
		print color('green'), "PTT_IN_PIN red changed to $PTT_in\n", color('reset');
		TetraLogic::transmitterStateChange(!$PTT_in);
	}

	if ($AUX_in != $AUX_in_old) {
		$AUX_in_old = $AUX_in;
		print color('green'), "AUX_IN_PIN blue changed to $AUX_IN_PIN\n", color('reset');

	}

	if ($PTT_2_out != $PTT_2_out_old) {
		$PTT_2_out_old = $PTT_2_out;
		print color('green'), "PTT_2_OUT_PIN orange changed to $PTT_2_out\n", color('reset');
		TetraLogic::transmitterStateChange(!$PTT_2_out);
	}

	if ($SQL_2_in != $SQL_2_in_old) {
		$SQL_2_in_old = $SQL_2_in;
		print color('green'), "SQL_2_IN_PIN green changed to $SQL_2_IN_PIN\n", color('reset');

	}
}



#################################################################################
# Main Loop #####################################################################
#################################################################################
sub MainLoop {
	while ($Run) {
		my $Scan = 0;
		(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime();

		TetraLogic::initPei();
#		Read_Serial(); # Serial Port Receiver when Mode == 0.
		TetraLogic::Read_Serial(); # Serial Port Receiver when Mode == 0.

		TetraLogic::peiComTimer();
		TetraLogic::peiActivityTimer();
		TetraLogic::peiBreakCommandTimer();

#		getEnvVars();
		GPIOs();

		nanosleep(010000000); # 2 ms



		APRS_Timer(); # APRS-IS Timer to send position/objects to APRS-IS.
		HotKeys(); # Keystrokes events.
		if ($Verbose >= 5) { print "Looping the right way.\n"; }
		#my $NumberOfTalkGroups = scalar keys %TG;
		#print "Total number of links is: $NumberOfTalkGroups\n\n";
	}
}

