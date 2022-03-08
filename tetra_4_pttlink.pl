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
print "	Released: March 06, 2022. Created March 01, 2022.\n";
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
my $Callsign = $cfg->val('Settings', 'Callsign');
my $SiteName = $cfg->val('Settings', 'SiteName');
my $SiteInfo = $cfg->val('Settings', 'SiteInfo');
my $Verbose = $cfg->val('Settings', 'Verbose');
print "	Mode = $Mode\n";
print "	HotKeys = $HotKeys\n";
print "	Callsign = $Callsign\n";
print "	SiteName = $SiteName\n";
print "	SiteInfo = $SiteInfo\n";
print "	Verbose = $Verbose\n";
print "----------------------------------------------------------------------\n";



# TETRA Init.
print color('green'), "Init TETRA.\n", color('reset');
my $mcc = $cfg->val('TETRA', 'MCC');
my $mnc = $cfg->val('TETRA', 'MNC');
my $issi = $cfg->val('TETRA', 'RadioISSI');
my $Serial_Port_Path = $cfg->val('TETRA', 'Serial_Port_Path');
my $Baudrate = $cfg->val('TETRA', 'Baudrate');
my $TETRA_Verbose = $cfg->val('TETRA', 'Verbose');
print "	mcc = $mcc\n";
print "	mnc = $mnc\n";
print "	issi = $issi\n";
print "	Serial_Port_Path = $Serial_Port_Path\n";
print "	Baudrate = $Baudrate\n";
print "	TETRA_Verbose = $TETRA_Verbose\n";

struct( Tetralogic => [
	mute_rx_on_tx => '$',
	mute_tx_on_rx => '$',
	rgr_sound_always => '$',
	mcc	=> '$',
	mnc	=> '$',
	issi => '$',
	gssi => '$',
	initstr => '$',
	pei => '$',
	sds_pty => '$',
	peistream => '$',
	talkgroup_up => '$',
	sds_when_dmo_on => '$',
	sds_when_dmo_off => '$',
	sds_when_proximity => '$',
	proximity_warning => '$',
	time_between_sds => '$',
	endCmd => '$',
	new_sds => '$',
	inTransmission => '$',
	cmgs_received => '$',
	share_userinfo => '$',
	current_cci => '$',
	dmcc => '$',
	dmnc => '$',
	infosds => '$',
]);

my $mute_rx_on_tx = 1;
my $mute_tx_on_rx = 1;
my $rgr_sound_always = 0;
my $gssi = 1;
my $initstr = '';
my $pei = '';
my $sds_pty = 0;
my $peistream = '';
my $talkgroup_up = 0;
my $sds_when_dmo_on = 0;
my $sds_when_dmo_off = 0;
my $sds_when_proximity = 0;
my $proximity_warning = 3.1;
my $time_between_sds = 3600;
my $endCmd = '';
my $new_sds = 0;
my $inTransmission = 0;
my $cmgs_received = 1;
my $share_userinfo = 1;
my $current_cci = 0;
my $dmcc = 0;
my $dmnc = 0;
my $infosds = '';

my $AT_NextTimer = 0;
my $AT_Timeout = 0;
my $AT_TimerInterval = 4; # Seconds.
my $AT_TimerEnabled = 0;

struct( Timer => [
	enabled => '$',
	oneshot => '$',
	interval => '$',
	timeout => '$',
]);

my $peiComTimer = Timer->new(interval=>2, oneshot=>1, enabled=>0, timeout=>time() + 2);
my $peiActivityTimer = Timer->new(interval=>10, oneshot=>1, enabled=>1, timeout=>time());
my $peiBreakCommandTimer = Timer->new(interval=>3, oneshot=>1, enabled=>0, timeout=>time() + 3);


my $peistate;

my $IDLE = 0;
my $CHECK_AT = 1;
my $INIT = 2;
my $IGNORE_ERRORS = 3;
my $INIT_COMPLETE = 4;
my $WAIT = 5;
my $AT_CMD_WAIT = 6;

my $peirequest = $AT_CMD_WAIT;
my $InitCounter = 0;
my $last_sdsinstance = '';
my $tetra_modem_sql = 0;
my $AT_Buffer = ''; # Clear AT Rx buffer.
# Timer
my $pei_TimerEnabled = 1;
my $pei_NextTimer = 0;
my $pei_Timeout = 0;
my $pei_TimerInterval = 10; # Seconds.


# Constants
my $OK = 0;
my $ERROR = 1;
my $CALL_BEGIN = 3;
my $GROUPCALL_END = 4;

my $SDS = 6;
my $TEXT_SDS = 7;
my $CNUMF = 8;
my $CALL_CONNECT = 9;
my $TRANSMISSION_END = 10;
my $CALL_RELEASED = 11;
my $LIP_SDS = 12;
my $REGISTER_TSI = 13;
my $STATE_SDS = 14;
my $OP_MODE = 15;
my $TRANSMISSION_GRANT = 16;
my $TX_DEMAND = 17;
my $TX_WAIT = 18;
my $TX_INTERRUPT = 19;
my $SIMPLE_LIP_SDS = 20;
my $COMPLEX_SDS = 21;
my $MS_CNUM = 22;
my $WAP_PROTOCOL = 23;
my $SIMPLE_TEXT_SDS = 24;
my $ACK_SDS = 25;
my $CMGS = 26;
my $CONCAT_SDS = 27;
my $CTGS = 28;
my $CTDGR = 29;
my $CLVL = 30;
my $OTAK = 31;
my $WAP_MESSAGE = 32;
my $LOCATION_SYSTEM_TSDU = 33;

my $DMO_OFF = 7;
my $DMO_ON = 8;

my $INVALID = 254;
my $TIMEOUT = 255;

my $LOGERROR = 0;
my $LOGWARN =1;
my $LOGINFO = 2;
my $LOGDEBUG = 3;
my $LOGDEBUG1 = 4;
my $LOGDEBUG2 = 5;
my $LOGDEBUG3 = 6;

my $TETRA_LOGIC_VERSION = '19122021';


my $RADIUS = 6378.16; # Earth radius

# AI Service;
# This parameter is used to determine the type of service to be used;
# in air interface call set up signalling. The services are all;
# defined in EN 300 392-2 [3] or EN 300 396-3 [25].;
my $TETRA_SPEECH=0;
my $UNPROTECTED_DATA=1;
my $PACKET_DATA=8;
my $SDS_TYPE1=9;
my $SDS_TYPE2=10;
my $SDS_TYPE3=11;
my $SDS_TYPE4=12;
my $STATUS_SDS=13;

# direction of Sds;
my $OUTGOING = 0;
my $INCOMING = 1;

# type of Sds;
my $STATE = 0;
my $TEXT = 1;
my $LIP_SHORT = 2;
my $COMPLEX_SDS_TL = 3;
my $RAW = 4;

# Sds sent state;
my $SDS_SEND_OK = 4;
my $SDS_SEND_FAILED = 5;


my $RadioID_URL = 'https://database.radioid.net/api/dmr/';


struct( Call => [
	mute_rx_on_tx => '$',
	mute_tx_on_rx => '$',
	rgr_sound_always => '$',
	mcc => '$',
	mnc => '$',
	issi => '$',
	gssi => '$',
	port => '$',
	baudrate => '$',
	initsrt => '$',
	pei => '$',
	sds_pty => '$',
	dapnetclient => '$',
]);

my $caller = Call->new();	# allocate an empty Person struct

$caller->mcc(901);			# set its name field
$caller->mnc(16383);		# set its age field
$caller->issi(33401010);	# set its peers field

print "caller " . $caller->mcc . "\n";

struct( Callinfo => [
	instance => '$',
	callstatus => '$',
	aistatus => '$',
	origin_cpit => '$',
	o_mcc => '$',
	o_mnc => '$',
	o_issi => '$',
	hook => '$',
	simplex => '$',
	e2eencryption => '$',
	commstype => '$',
	codec => '$',
	dest_cpit => '$',
	d_mcc => '$',
	d_mnc => '$',
	d_issi => '$',
	prio => '$',
]);

my @callinfo = Callinfo->new();

struct( QsoInfo => [
	tsi => '$',
	start => '$',
	stop => '$',
	members => "@",
]);

my $Qso = QsoInfo->new();

struct( Sds => [
	id => '$',
	tsi => '$',
	remark => '$',
	message => '$',
	tos => '$',
	tod => '$',
	type => '$',
	direction => '$',
	nroftries => '$',
	aiservice => '$',
]);

my $pending_sds = Sds->new();

struct( User => [
	issi => '$',
	call => '$',
	name => '$',
	comment => '$',
	location => '$',
	lat => '$',
	lon => '$',
	_state => '$',
	reasonforsending => '$',
	aprs_sym => '$',
	aprs_tab => '$',
	last_activity => '$',
	sent_last_sds => '$',
]);

my @userdata = User->new();

struct( DmoRpt => [
	issi => '$',
	mni => '$',
	_state => '$',
	last_activity => '$',
]);

struct( pSds => [
	sdstype => '$',
	aiservice => '$',
	fromtsi => '$',
	totsi => '$',
	last_activity => '$',
]);

struct( LipInfo => [
	time_elapsed => '$',
	latitude => '$',
	longitude => '$',
	positionerror => '$',
	horizontalvelocity => '$',
	directionoftravel => '$',
	reasonforsending => '$',
]);

my $LinkedTalkGroup = 0;
print "----------------------------------------------------------------------\n";



# Init Serial Port for AT.
print color('green'), "Init Serial Port.\n", color('reset');
my $SerialPort;
my $SerialPort_Configuration = "SerialConfig.cnf";

if ($Mode == 0) {
	# For Mac:
	if ($OS eq "darwin") {
		$SerialPort = Device::SerialPort->new('/dev/tty.usbserial') || die "Cannot Init Serial Port : $!\n";
	}
	# For Linux:
	if ($OS eq "linux") {
		$SerialPort = Device::SerialPort->new('/dev/ttyUSB0') || die "Cannot Init Serial Port : $!\n";
	}
	$SerialPort->baudrate($Baudrate);
	$SerialPort->databits(8);
	$SerialPort->parity('none');
	$SerialPort->stopbits(1);
	$SerialPort->handshake('none');
	$SerialPort->buffers(4096, 4096);
	$SerialPort->datatype('raw');
	$SerialPort->debug(1);
	#$SerialPort->write_settings || undef $SerialPort;
	#$SerialPort->save($SerialPort_Configuration);
	#$TickCount = sprintf("%d", $SerialPort->get_tick_count());
	#$FutureTickCount = $TickCount + 5000;
	#print "	TickCount = $TickCount\n\n";
	print color('yellow'),
		"To use Raspberry Pi UART you need to disable Bluetooth by editing: /boot/config.txt\n" .
		"Add line: dtoverlay=pi3-disable-bt-overlay\n", color('reset'),;
}
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
my $PTT_GPIO = $cfg->val('GPIO', 'PTT_GPIO');
my $SQL_GPIO = $cfg->val('GPIO', 'SQL_GPIO');
my $AUX_GPIO = $cfg->val('GPIO', 'AUX_GPIO');
print "	PTT_GPIO = $PTT_GPIO\n";
print "	SQL_GPIO = $SQL_GPIO\n";
print "	AUX_GPIO = $AUX_GPIO\n";
print "	GPIO_Verbose = $Verbose\n";

my $PTT = RPi::Pin->new($PTT_GPIO, "PTT_GPIO");
my $SQL = RPi::Pin->new($SQL_GPIO, "SQL_GPIO");
my $AUX = RPi::Pin->new($AUX_GPIO, "AUX_GPIO");
# This use the BCM pin numbering scheme. 
# Valid GPIOs are: 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27.
# GPIO 2, 3 Aleternate for I2C.
# GPIO 14, 15 alternate for USART.
$PTT->mode(INPUT);
$SQL->mode(OUTPUT);
$AUX->mode(OUTPUT);
$PTT->write(HIGH);
$PTT->set_interrupt(EDGE_RISING, 'main::PTT_Interrupt_Handler');
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



##################################################################
# Serial #########################################################
##################################################################
sub Read_Serial { # Read the serial port, look for 0x7E characters and extract data between them.
	if ($Mode |= 0) { return; }
	my $NumChars;
	my $SerialBuffer;
	($NumChars, $SerialBuffer) = $SerialPort->read(255);
	if ($NumChars >= 1 ){ #Perl data Arrival test.
		#Bytes_2_HexString($SerialBuffer);
		for (my $x = 0; $x <= $NumChars; $x++) {
			if (ord(substr($SerialBuffer, $x, 1)) == 0x0D) {
				if (length($AT_Buffer) > 0) {
					print color('green'), "Serial_Rx\n", color('reset');
					#print "\tSerial Rx len() = " . length($AT_Buffer) . "\n";
					TETRA_Rx($AT_Buffer);
					if ($TETRA_Verbose >= 2) {print "\tRx line = " . $AT_Buffer . "\n";}
					if ($TETRA_Verbose >= 3) {Bytes_2_HexString($AT_Buffer);}
				}
				#print "\tRead_Serial len = " . length($AT_Buffer) . "\n";
				$AT_Buffer = ""; # Clear Rx buffer.
			} elsif (ord(substr($SerialBuffer, $x, 1)) == 0x0A){
				# Do nothing
			} else {
				# Add Bytes until the end of data stream (0x7E):
				$AT_Buffer .= substr($SerialBuffer, $x, 1);
			}
		}
	}
}



###############################################################################
# TetraLogic ##################################################################
###############################################################################
sub transmitterStateChange {
	my ($is_transmitting) = @_;
	
	if ($is_transmitting) {
		if (not $talkgroup_up) {
			initGroupCall($gssi);
			$talkgroup_up = 1;
		} else {
			my $cmd = 'AT+CTXD=' . $current_cci . ',1';
			TETRA_Tx($cmd);
		}
	} else {
		my $cmd = 'AT+CUTXC=' . $current_cci;
		TETRA_Tx($cmd);
	}
	if ($mute_rx_on_tx) {
#		rx().setMuteState(is_transmitting ? Rx::MUTE_ALL : Rx::MUTE_NONE);
	}
#	Logic::transmitterStateChange(is_transmitting);
}

###############################################################################
sub squelchOpen {
	my ($is_open) = @_;

	#if (tx().isTransmitting()):
	#	return;

	$tetra_modem_sql = $is_open;
#	setSql($is_open);
	#rx().setSql(is_open);
	#Logic::squelchOpen(is_open); # GPIO19 = SQL
#	GPIO.output(settings.SQL_GPIO, not is_open);

	if ($is_open){
		system("sudo python change_sql.py --sql 0");
#		system("VAR_SQL = 0");
		system("/usr/sbin/asterisk -rx \"iax2 show registry\"");
	} else {
		system("sudo python change_sql.py --sql 1");
#		system("VAR_SQL = 1");
		system("/usr/sbin/asterisk -rx \"iax2 show registry\"");
	}
}



###############################################################################
# PEI #########################################################################
###############################################################################
# Initialize the Pei device, here some commends that being used
# to (re)direct the answers to the Pei port. See EN 300 392-5
# V2.2.0 manual, page 62 for further info
# TETRA Service Profile +CTSP:
# +CTSP=<service profile>, <service layer1>, [<service layer2>],
#       [<AI mode>], [<link identifier>]
# AT+CTOM=1           set MRT into DMO-MS mode (0-TMO, 6-DMO-Repeater)
# AT+CTSP=1,3,131     Short Data Service type 4 with Transport Layer (SDS-TL)
#                     service
#                     131 - GPS
# AT+CTSP=1,3,130     130 - Text Messaging
# AT+CTSP=1,2,20      Short Data Service (SDS)
#                     20 - Status
# AT+CTSP=2,0,0       0 - Voice
# AT+CTSP=1,3,24      24 - SDS type 4, PID values 0 to 127
# AT+CTSP=1,3,25      25 - SDS type 4, PID values 128 to 255
# AT+CTSP=1,3,3       3 - Simple GPS
# AT+CTSP=1,3,10      10 - Location information protocol
# AT+CTSP=1,1,11      11 - Group Management
# TETRA service definition for Circuit Mode services +CTSDC
# +CTSDC=<AI service>, <called party identity type>, [<area>], [<hook>],
#        [<simplex>], [<end to end encryption>],[<comms type>],
#        [<slots/codec>], [<RqTx>], [<priority>], [<CLIR control>]
# AT+CTSDC=0,0,0,1,1,0,1,1,0,0
sub initPei {
	#global peiBreakCommandTimer
	my $cmd;
	if ($peirequest == $AT_CMD_WAIT) {
		$peiBreakCommandTimer->timeout(time() + $peiBreakCommandTimer->interval);
		$peiBreakCommandTimer->enabled(1);
#		$Run = 0;
	}
	if ($InitCounter < 14) {
		switch ($InitCounter) {
			case 0 {
				$cmd = '';
				TETRA_Tx($cmd);
				nanosleep(002000000); # 2 ms
				$InitCounter++;
			}
			case 1 {
				$cmd = 'AT';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 2 {
				$cmd = 'AT+CTOM=6,0';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 3 {
				$cmd = 'AT+CTSP=1,3,131';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 4 {
				$cmd = 'AT+CTSP=1,3,130';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 5 {
				$cmd = 'AT+CTSP=1,3,138';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 6 {
				$cmd = 'AT+CTSP=1,2,20';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 7 {
				$cmd = 'AT+CTSP=2,0,0';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 8 {
				$cmd = 'AT+CTSP=1,3,24';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 9 {
				$cmd = 'AT+CTSP=1,3,25';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 10 {
				$cmd = 'AT+CTSP=1,3,3';
				TETRA_Tx($cmd);;
				$InitCounter++;
			}
			case 11 {
				$cmd = 'AT+CTSP=1,3,10';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 12 {
				$cmd = 'AT+CTSP=1,1,11';
				TETRA_Tx($cmd);
				$InitCounter++;
			}
			case 13 {
				$cmd = "AT+CTSDC=0,0,0,1,1,0,1,1,0,0";
				TETRA_Tx($cmd);
				$InitCounter++;
#print "Bla $InitCounter\n";
			}
		}
		print "***** $peirequest **********************************\n";
	} elsif ($peirequest == $INIT) {
		$cmd = "AT+CNUMF?"; # get the MCC,MNC,ISSI from MS
		TETRA_Tx($cmd);
		my $ss = "pei_init_finished\n";
		print $ss;
		sendUserInfo(); # send userinfo to reflector
		$peirequest = $INIT_COMPLETE;
		print color('magenta'), "TETRA Pei Init Complete\n", color('reset');
	}
}

####################################################
sub sendUserInfo {
	my ($is_open) = @_;

# To Do

	return;
}

####################################################
sub handlePeiAnswer {
	my ($m_message) = @_;
	my $response = '';

	if ($TETRA_Verbose >= $LOGINFO) {
		print "From PEI:" . $m_message . "\n";
		#print " length(m_message)" + str(length(m_message));
	}
	
	if ($m_message eq "OK") {
		$peistate = $OK;
		if ($new_sds and !$inTransmission) {
			checkSds();
		}
	} elsif (rindex($m_message, "+CME ERROR:", 0) == 0) {
		$peistate = $ERROR;
		if ((length($m_message) > 11) and ($TETRA_Verbose >= $LOGINFO)) {
			my $Error = substr($m_message, 11);
			print color('yellow'), " +CME ERROR: " . getPeiError($Error) . "\n", color('reset');
		}
	} elsif (rindex($m_message, "+CNUMF:", 0) == 0) { # CNUMF, Local Radio MCC, MNC and ISSI
		handleCnumf($m_message);
	} elsif (rindex($m_message, "+CTICN:", 0) == 0) { # CALL_BEGIN
		handleCallBegin($m_message);
	} elsif (rindex($m_message, "+CDTXC:", 0) == 0) { # TRANSMISSION_END
		handleTransmissionEnd($m_message);
	} elsif (rindex($m_message, "+CTCR:", 0) == 0) { # CALL_RELEASED
		handleCallReleased($m_message);
	} elsif (rindex($m_message, "+CTSDSR:", 0) == 0) { # SDS
		handleSds($m_message);
	#elif (m_message[0 : 7] == '^8210[0-9A-F {4}' { # ACK_SDS
	} elsif (rindex($m_message, "8210", 0) == 0) { # ACK_SDS
		print "ACK_SDS";
	#elif (m_message[0 : 7] == '8[23 [0-9A-F {3,}' { # TEXT_SDS
	} elsif (rindex($m_message, "8", 0) == 0) { # TEXT_SDS
		handleSdsMsg($m_message);
	} elsif (rindex($m_message, "02", 0) == 0) { # SIMPLE_TEXT_SDS
		handleSdsMsg($m_message);
	#elif (m_message[0 : 7] == '[8-9A-F [0-9A-F {3}$' { # STATE_SDS
	} elsif ((length($m_message) == 4) and # STATE_SDS
			((ord(substr($m_message, 0, 1)) >= 0x38) and (ord(substr($m_message, 0, 1)) <= 0x39)) and
			((ord(substr($m_message, 1, 2)) >= 0x30) and (ord(substr($m_message, 1, 2)) <= 0x39) or
			(ord(substr($m_message, 1, 2)) >= 0x41) and (ord(substr($m_message, 1, 2)) <= 0x46)) and
			((ord(substr($m_message, 2, 3)) >= 0x30) and (ord(substr($m_message, 2, 3)) <= 0x39) or
			(ord(substr($m_message, 2, 3)) >= 0x41) and (ord(substr($m_message, 2, 3)) <= 0x46)) and
			((ord(substr($m_message, 3, 4)) >= 0x30) and (ord(substr($m_message, 3, 4)) <= 0x39) or
			(ord(substr($m_message, 3, 4)) >= 0x41) and (ord(substr($m_message, 3, 4)) <= 0x46))) {
		handleSdsMsg($m_message);
	#} elsif ($m_message[0 : 1] == '') { # COMPLEX_SDS
		#handleSdsMsg($m_message);
	} elsif (rindex($m_message, "0C", 0) == 0) { # CONCAT_SDS
		handleSdsMsg($m_message);
	} elsif ((rindex($m_message, "0A", 0) == 0) and # LIP_SDS
			((ord(substr($m_message, 2, 3)) >= 0x30) and (ord(substr($m_message, 2, 3)) <= 0x39) or
			(ord(substr($m_message, 2, 3)) >= 0x41) and (ord(substr($m_message, 2, 3)) <= 0x46)) and
			((ord(substr($m_message, 3, 4)) >= 0x30) and (ord(substr($m_message, 3, 4)) <= 0x39) or
			(ord(substr($m_message, 3, 4)) >= 0x41) and (ord(substr($m_message, 3, 4)) <= 0x46)) and
			((ord(substr($m_message, 4, 5)) >= 0x30) and (ord(substr($m_message, 4, 5)) <= 0x39) or
			(ord(substr($m_message, 4, 5)) >= 0x41) and (ord(substr($m_message, 4, 5)) <= 0x46)) and
			((ord(substr($m_message, 5, 6)) >= 0x30) and (ord(substr($m_message, 5, 6)) <= 0x39) or
			(ord(substr($m_message, 5, 6)) >= 0x41) and (ord(substr($m_message, 5, 6)) <= 0x46)) and
			((ord(substr($m_message, 6, 7)) >= 0x30) and (ord(substr($m_message, 6, 7)) <= 0x39) or
			(ord(substr($m_message, 6, 7)) >= 0x41) and (ord(substr($m_message, 6, 7)) <= 0x46)) and
			((ord(substr($m_message, 7, 8)) >= 0x30) and (ord(substr($m_message, 7, 8)) <= 0x39) or
			(ord(substr($m_message, 7, 8)) >= 0x41) and (ord(substr($m_message, 7, 8)) <= 0x46)) and
			((ord(substr($m_message, 8, 9)) >= 0x30) and (ord(substr($m_message, 8, 9)) <= 0x39) or
			(ord(substr($m_message, 8, 9)) >= 0x41) and (ord(substr($m_message, 8, 9)) <= 0x46)) and
			((ord(substr($m_message, 9, 10)) >= 0x30) and (ord(substr($m_message, 9, 10)) <= 0x39) or
			(ord(substr($m_message, 9, 10)) >= 0x41) and (ord(substr($m_message, 9, 10)) <= 0x46)) and
			((ord(substr($m_message, 10, 11)) >= 0x30) and (ord(substr($m_message, 10, 11)) <= 0x39) or
			(ord(substr($m_message, 10, 11)) >= 0x41) and (ord(substr($m_message, 10, 11)) <= 0x46)) and
			((ord(substr($m_message, 11, 12)) >= 0x30) and (ord(substr($m_message, 11, 12)) <= 0x39) or
			(ord(substr($m_message, 11, 12)) >= 0x41) and (ord(substr($m_message, 11, 12)) <= 0x46)) and
			((ord(substr($m_message, 12, 13)) >= 0x30) and (ord(substr($m_message, 12, 13)) <= 0x39) or
			(ord(substr($m_message, 12, 13)) >= 0x41) and (ord(substr($m_message, 12, 13)) <= 0x46)) and
			((ord(substr($m_message, 13, 14)) >= 0x30) and (ord(substr($m_message, 13, 14)) <= 0x39) or
			(ord(substr($m_message, 13, 14)) >= 0x41) and (ord(substr($m_message, 13, 14)) <= 0x46))) {
		handleSdsMsg($m_message);
	} elsif (rindex($m_message, "+CMGS:", 0) == 0) { # CMGS
		# +CMGS: <SDS Instance>[, <SDS status> [, <message reference>]]
		# sds state send be MS
		handleCmgs($m_message);
	} elsif (rindex($m_message, "+CTXD:", 0) == 0) { # TX_DEMAND
		# NOP
	} elsif (rindex($m_message, "+CTXG:", 0) == 0) { # TRANSMISSION_GRANT
		handleTxGrant($m_message);
	} elsif (rindex($m_message, "+CTCC:", 0) == 0) { # CALL_CONNECT
		$current_cci = handleCci($m_message);
	#elif ($m_message[0 : 7] == '+CTOM: [0-9 $' { # OP_MODE
	} elsif ((rindex($m_message, "+CTOM:", 0) == 0) and # OP_MODE
		(ord(substr($m_message, 7, 8)) >= 0x30) and (ord(substr($m_message, 7, 8)) <= 0x39)) {
		getAiMode($m_message);
	} elsif (rindex($m_message, "+CTGS:", 0 ) == 0) { # CTGS
		handleCtgs($m_message);
	} elsif (rindex($m_message, "+CTDGR:", 0) == 0) { # CTDGR
		handleCtdgr($m_message);
	} elsif (rindex($m_message, "+CLVL:", 0) == 0) { # CLVL
		handleClvl($m_message);
	} elsif (rindex($m_message, "INVALID", 0) == 0) {
		if ($TETRA_Verbose >= $LOGWARN) {
			warn color('yellow'), "+++ Pei answer not known, ignoring.", color('reset');
		}
	} else {
		if ($TETRA_Verbose >= $LOGWARN) {
			warn color('yellow'), "Uknown Command m_message = " . $m_message . "\n";
			print " Len(m_message) = " . length($m_message) . "\n", color('reset');
		}
	}
	if (($peirequest == $INIT) and (($response == $OK) or ($response == $ERROR))) {
		initPei();
	}
}

####################################################
sub initGroupCall {
	my ($gc_gssi) = @_;
	$inTransmission = 1;
	my $cmd = "AT+CTSDC=0,0,0,1,1,0,1,1,0,0,0";
	TETRA_Tx($cmd);

	$cmd = "ATD";
	$cmd = $cmd. $gc_gssi;
	TETRA_Tx($cmd);
	
	my $ss;
	$ss = "init_group_call " . $gc_gssi . "\n";
	print $ss;
#	processEvent(ss.str());
}

####################################################
# TETRA Incoming Call Notification +CTICN
# +CTICN: <CC instance >, <call status>, <AI service>,
# [<calling party identity type>], [<calling party identity>],
# [<hook>], [<simplex>], [<end to end encryption>],
# [<comms type>], [<slots/codec>], [<called party identity type>],
# [<called party identity>], [<priority level>]
#  Example:        MCC| MNC| ISSI  |             MCC| MNC|  GSSI |
#  +CTICN: 1,0,0,5,09011638300023404,1,1,0,1,1,5,09011638300000001,0
#  OR               ISSI             GSSI
#  +CTICN: 1,0,0,5,23404,1,1,0,1,1,5,1000,0
sub handleCallBegin {
	my ($message) = @_;
	#     +CTICN:   1,    0,    0,    4,    1002,       1,     1,     0,   1,    1,   0,    1000,       1
	my $reg = "\\+CTICN: [0-9],[0-9],[0-9],[0-9],[0-9]{1,17},[0-9],[0-9],[0-9],[0-9],[0-9],[0-9],[0-9]{1,17},[0-9]";

#	if ( not $rmatch($message, $reg)) {
#		if ($TETRA_Verbose >= $LOGWARN) {
#			print "*** Wrong +CTICN response (wrong format)";
#		}
#		return;
#	}
	squelchOpen(1); # open the Squelch

	my $t_ci = Callinfo->new();
	my $ss;
	substr($message, 0, 8) = ""; # Replace in a string (used here to erase)
	my $h = $message;

	# split the message received from the Pei into single parameters
	# for further use, not all of them are interesting
	$t_ci->instance(getNextVal($h));
	$t_ci->callstatus(getNextVal($h));
	$t_ci->aistatus(getNextVal($h));
	$t_ci->origin_cpit(getNextVal($h));

	my $o_tsi = getNextStr($h);

	if (length($o_tsi) < 9) {
		$t_ci->o_issi(int($o_tsi));
		my $t = $mcc;
		$t += $mnc;
		$t += getISSI($o_tsi);
		$o_tsi = $t;
		$t_ci->o_mnc($dmnc);
		$t_ci->o_mcc($dmcc);
	} else {
		splitTsi($o_tsi, $t_ci->o_mcc, $t_ci->o_mnc, $t_ci->o_issi);
	}

	$t_ci->hook(getNextVal($h));
	$t_ci->simplex(getNextVal($h));
	$t_ci->e2eencryption(getNextVal($h));
	$t_ci->commstype(getNextVal($h));
	$t_ci->codec(getNextVal($h));
	$t_ci->dest_cpit(getNextVal($h));

print "HHHH $h\n";

	my $d_tsi = getNextStr($h);

	if (length($d_tsi) < 9) {
		$t_ci->d_issi(int($d_tsi));
		my $t = $mcc;
		$t += $mnc;
		$t += getISSI($d_tsi);
		$d_tsi = $t;
		$t_ci->d_mnc($dmnc);
		$t_ci->d_mcc($dmcc);
	} else {
		splitTsi($d_tsi, $t_ci->d_mcc, $t_ci->d_mnc, $t_ci->d_issi);
	}

	$t_ci->prio(int($h));

	# store call specific data into a Callinfo struct
	$callinfo[$t_ci->instance] = $t_ci;

	# check if the user is stored? no -> default
#	std::map<std::string, User>::iterator iu = userdata.find(o_tsi);
#	if ($iu == userdata.end()) {
		my $t_sds = Sds->new();
		$t_sds->direction($OUTGOING);
		$t_sds->message($infosds);
		$t_sds->tsi($o_tsi);
		$t_sds->type($TEXT);
		firstContact($t_sds);
#		return;
#	}

#	$userdata[$o_tsi]->last_activity(time());

	# store info in Qso struct
	$Qso->tsi($o_tsi);
	$Qso->start(time());

	# prepare event for tetra users to be send over the network
#	Json::Value qsoinfo(Json::objectValue);

#	qsoinfo["qso_active"] = true;
#	qsoinfo["gateway"] = callsign();
#	qsoinfo["dest_mcc"] = t_ci.d_mcc;
#	qsoinfo["dest_mnc"] = t_ci.d_mnc;
#	qsoinfo["dest_issi"] = t_ci.d_issi;
#	qsoinfo["aimode"] = t_ci.aistatus;
#	qsoinfo["cci"] = t_ci.instance;
#	uint32_t ti = time(NULL);
#	qsoinfo["last_activity"] = ti;

#	std::list<std::string>::iterator it;
#	$it = find(Qso.members.begin(), Qso.members.end(), iu->second.call);
#	if ($it == $Qso.members.end()) {
#		$Qso.members.push_back(iu->second.call);
#	}

#	$qsoinfo["qso_members"] = joinList(Qso.members);
#	publishInfo("QsoInfo:state", qsoinfo);
	# end of publish messages

	# callup tcl event
	$ss = "groupcall_begin " . $t_ci->o_issi . " " . $t_ci->d_issi . "\n";
	print $ss;
#	processEvent($ss);

#	stringstream m_aprsmesg;
#	$m_aprsmesg = $aprspath . ">" . $iu->second.call . " initiated groupcall: " .
#		$t_ci.o_issi . " -> " . t_ci.d_issi;
#	sendAprs(iu->second.call, $m_aprsmesg);
}

####################################################
# TETRA SDS Receive +CTSDSR
# CTSDSR unsolicited Result Codes
# +CTSDSR: <AI service>, [<calling party identity>],
# [<calling party identity type>], <called party identity>,
# <called party identity type>, <length>,
# [<end to end encryption>]<CR><LF>user data
# Example:
# +CTSDSR: 12,23404,0,23401,0,112
# (82040801476A61746A616A676A61)
sub handleSds {
	my ($m_message) = @_;

}

####################################################
sub firstContact {
	my ($tsds) = @_;
#	$userdata[$tsds->tsi]->call("NoCall");
#	$userdata[$tsds->tsi]->name("NoName");
#	$userdata[$tsds.tsi]->aprs_sym($t_aprs_sym);
#	$userdata[$tsds.tsi]->aprs_tab($t_aprs_tab);
#	$userdata[$tsds->tsi]->last_activity(time());

#	if (length($infosds) > 0) {
#		$tsds->direction($OUTGOING);
#		$tsds->message($infosds);
#		$tsds->type($TEXT);
#		$tsds->remark("Welcome Sds to a new user");
#		if ($TETRA_Verbose >= $LOGINFO) {
#			print "Sending info Sds to new user " . $tsds->tsi . " \"" .
#				$infosds . "\"\n";
#		}
#		queueSds($tsds);
#	}
}

####################################################
# Handle the sds message
# Example:
# (+CTSDSR: 12,23404,0,23401,0,112)
# 82040801476A61746A616A676A61
sub handleSdsMsg {
	my ($sds) = @_;

}

####################################################
# 6.15.6 TETRA Group Set up
# +CTGS [<group type>], <called party identity> ... [,[<group type>], 
#       < called party identity>]
# In V+D group type shall be used. In DMO the group type may be omitted,
# as it will be ignored.
# PEI: +CTGS: 1,09011638300000001
sub handleCtgs {
	my ($m_message) = @_;

}

####################################################
# 6.14.10 TETRA DMO visible gateways/repeaters
# * +CTDGR: [<DM communication type>], [<gateway/repeater address>], [<MNI>],
# *         [<presence information>]
# * TETRA DMO visible gateways/repeaters +CTDGR
# * +CTDGR: 2,1001,90116383,0
sub handleCtdgr {
	my ($m_message) = @_;

}

####################################################
sub handleClvl {
	my ($m_message) = @_;

}

####################################################
# CMGS Set and Unsolicited Result Code Text
# The set result code only indicates delivery to the MT. In addition to the 
# normal <OK> it contains a message reference <SDS instance>, which can be 
# used to identify message upon unsolicited delivery status report result 
# codes. For SDS-TL messages the SDS-TL message reference is returned. The 
# unsolicited result code can be used to indicate later transmission over 
# the air interface or the sending has failed.
# +CMGS: <SDS Instance>, [<SDS status>], [<message reference>]
# +CMGS: 0,4,65 <- decimal
# +CMGS: 0
sub handleCmgs {
	my ($m_message) = @_;

	substr($m_message, 0, 7) = ""; # Replace in a string (used here to erase)

	my $sds_inst = getNextVal($m_message);		# SDS instance
	my $state = getNextVal($m_message);		# SDS status: 4 - ok, 5 - failed
	my $id = getNextVal($m_message);			# message reference id

	if ($last_sdsinstance == $sds_inst) {
		if ($state == $SDS_SEND_FAILED) {
			if ($TETRA_Verbose>= $LOGERROR) {
				print color('red'), "*** ERROR: Send message failed. Will send again...\n", color('reset');
			}
			$pending_sds->tos = 0;
		} elsif ($state == $SDS_SEND_OK) {
			if ($TETRA_Verbose >= $LOGINFO) {
				print "+++ Message sent OK, #" . $id . "\n";
			}
			$cmgs_received = 1;
		}
	}
	$cmgs_received = 1;
	$last_sdsinstance = $sds_inst;
	checkSds();
	return;
}

####################################################
sub handleTextSds {
	my ($m_message) = @_;

}

####################################################
sub handleAckSds {
	my ($m_message, $tsi) = @_;

}

####################################################
sub handleSimpleTextSds {
	my ($m_message) = @_;

}

####################################################
# 6.15.10 Transmission Grant +CTXG
# +CTXG: <CC instance>, <TxGrant>, <TxRqPrmsn>, <end to end encryption>,
#        [<TPI type>], [<TPI>]
# e.g.:
# +CTXG: 1,3,0,0,3,09011638300023404
sub handleTxGrant {
	my ($txgrant) = @_;
	my $ss;
	squelchOpen(1); # open Squelch
	$ss = "tx_grant\n";
	print $ss
#	processEvent(ss.str());
}

####################################################
sub getTSI {
	my ($issi) = @_;

}

####################################################
sub handleStateSds {
	my ($isds) = @_;

	my $ss;
	if ($TETRA_Verbose >= $LOGINFO) {
		print "+++ State Sds received: " . $isds . "\n";
	}

#	std::map<unsigned int, string>::iterator it = sds_to_command.find(isds);

#	if ($it != sds_to_command.end()) {
		# to connect/disconnect Links
#		$ss << $it->second << "#";
#		injectDtmf(ss.str(), 10);
#	}

#	it = state_sds.find(isds);
#	if (it != state_sds.end()) {
		# process macro, if defined
#		$ss = "D" . $isds . "#\n";
#		injectDtmf(ss.str(), 10);
#	}
}

####################################################
# 6.15.11 Down Transmission Ceased +CDTXC
# * +CDTXC: <CC instance>, <TxRqPrmsn>
# * +CDTXC: 1,0
sub handleTransmissionEnd {
	my ($message) = @_;

	squelchOpen(0); # close Squelch
	my $ss;
	$ss = "groupcall_end\n";
#	processEvent($ss.str());
}

####################################################
# 6.15.3 TETRA Call ReleaseTETRA Call Release
# +CTCR: <CC instance >, <disconnect cause>
# +CTCR: 1,13
sub handleCallReleased {
	my ($message) = @_;

	$Qso->stop(time());

	my $ss;
	substr($message, 0, 7) = ""; # Replace in a string (used here to erase)
	my $cci = getNextVal($message);

	if ($tetra_modem_sql ==1) {
		squelchOpen(0); # close Squelch
		$ss = "out_of_range " . getNextVal($message) . "\n";
	} else {
		$ss = "call_end \"" . DisconnectCause(getNextVal($message)) . "\"\n";
	}
	print $ss;
#	processEvent($ss);

	# send call/qso end to aprs network
#	std::string m_aprsmesg = aprspath;
#	if (!Qso.members.empty()) {
#		m_aprsmesg += ">Qso ended (";
#		m_aprsmesg += joinList(Qso.members);
#		m_aprsmesg += ")";

		# prepare event for tetra users to be send over the network
#		Json::Value qsoinfo(Json::objectValue);

#		uint32_t ti = time(NULL);
#		qsoinfo["last_activity"] = ti;
#		qsoinfo["qso_active"] = false;
#		qsoinfo["qso_members"] = joinList(Qso.members);
#		qsoinfo["gateway"] = callsign();
#		qsoinfo["cci"] = cci;
#		qsoinfo["aimode"] = callinfo[cci].aistatus;
#		qsoinfo["dest_mcc"] = callinfo[cci].d_mcc;
#		qsoinfo["dest_mnc"] = callinfo[cci].d_mnc;
#		qsoinfo["dest_issi"] = callinfo[cci].d_issi;
#		publishInfo("QsoInfo:state", qsoinfo);
#	} else {
#		m_aprsmesg += ">Transmission ended";
#	}
#	sendAprs(userdata[Qso.tsi].call, m_aprsmesg);

	$talkgroup_up = 0;
#	Qso.members.clear();

	$inTransmission = 0;
	checkSds(); # resend Sds after MS got into Rx mode

}



####################################################
sub joinList {
	my ($members) = @_;

}

##################################################################
sub TETRA_Tx {
	my ($Buffer) = @_;

	if ($Mode == 0) { # Serial mode = 0;
		if ($TETRA_Verbose) {print color('green'), "TETRA_Tx.\n", color('reset');}
		$Buffer = $Buffer . chr(0x0D) . chr(0x0A);
		$SerialPort->write($Buffer);
		if ($TETRA_Verbose >= 2) {print "\t" . $Buffer . "\n";}
		if ($TETRA_Verbose >= 3) {Bytes_2_HexString($Buffer);}
	}
	if ($TETRA_Verbose) {print "\tTETRA_Tx Done.\n";}

	$peiComTimer->timeout(time() + $peiComTimer->interval);
	$peiComTimer->enabled(1);
}

####################################################
sub onComTimeout {
	my $ss = "peiCom_timeout\n";
	print $ss;
#	processEvent(ss);
	$peistate = $TIMEOUT;
}

####################################################
sub onPeiActivityTimeout {
	TETRA_Tx("AT");
	$peirequest = $CHECK_AT;
	$peiActivityTimer->timeout(time() + $peiActivityTimer->interval); # Reset()
}

####################################################
sub onPeiBreakCommandTimeout {
	$peirequest = $INIT;
	initPei();
}

####################################################
#Create a confirmation sds and sends them to the Tetra radio
sub cfmSdsReceived {
	my ($tsi) = @_;

	my $msg = "OK";
	my $t_sds = Sds->new();
	$t_sds->message = $msg;
	$t_sds->tsi = $tsi;
	$t_sds->direction = $OUTGOING;
	queueSds($t_sds);
}


####################################################
# +CTSDSR: 12,23404,0,23401,0,96, 82041D014164676A6D707477 */
sub cfmTxtSdsReceived {
	my ($message, $tsi) = @_;

	if (len($message) < 8) {
		return;
	}
	my $id = substr($message, 4, 2);
	my $msg = "821000"; # confirm a sds received
	$msg = $msg . $id;

	if ($TETRA_Verbose >= $LOGINFO) {
		print "+++ sending confirmation Sds to " . $tsi . "\n";
	}

	my $t_sds = Sds->new();
	$t_sds->message = $msg;
	$t_sds->id = hex2int($id);
	$t_sds->remark = "confirmation Sds";
	$t_sds->tsi = $tsi;
	$t_sds->type = $ACK_SDS;
	$t_sds->direction = $OUTGOING;
	queueSds($t_sds);
}

####################################################
sub handleCnumf {
	my ($m_message) = @_;

	if (rindex($m_message, "+CNUMF: ", 0) == 0) {
		substr($m_message, 0, 8) = ""; # Replace in a string (used here to erase)
	}
	# e.g. +CNUMF: 6,09011638300023401

	print color('magenta'), "Rx +CNUMF:$m_message\n", color('reset');
	my $t_mcc;
	my $t_mnc;
	my $t_issi;

	my $m_numtype = getNextVal($m_message);
	
	if ($TETRA_Verbose >= $LOGINFO) {
		print "<num type> is " . $m_numtype . " (" .
			NumType($m_numtype) . ")\n";
	}
	if ($m_numtype == 6 || $m_numtype == 0) {
		# get the tsi and split it into mcc,mnc,issi
		splitTsi($m_message, $t_mcc, $t_mnc, $t_issi);
		# check if the configured MCC fits to MCC in MS
		if ($t_mcc != $mcc) {
			if ($TETRA_Verbose >= $LOGWARN) {
				print color('red'), "*** ERROR: wrong MCC in MS, will not work! " .
					$mcc . "!=" . $t_mcc . "\n", color('reset');
			}
		}

		 # check if the configured MNC fits to MNC in MS
		if ($t_mnc != $mnc) {
			if ($TETRA_Verbose >= $LOGWARN) {
				print color('red'), "*** ERROR: wrong MNC in MS, will not work! " .
					$mnc . "!=" . $t_mnc . "\n", color('reset');
			}
		}
		$dmcc = $t_mcc;
		$dmnc = $t_mnc;

		if ($issi != $t_issi) {
			if ($TETRA_Verbose >= $LOGWARN) {
				print color('red'), "*** ERROR: wrong ISSI in MS, will not work! " .
					$issi . "!=" . $t_issi . "\n", color('reset');
			}
		}
	}

	$peirequest = $INIT_COMPLETE;
}



####################################################
sub sdsPtyReceived {
	my ($buf, $size) = @_;

}

####################################################
sub sendInfoSds {
	my ($tsi, $reason) = @_;

}

####################################################
sub handleMessage {
	my ($mesg) = @_;

	my $retvalue = $INVALID;



}

####################################################
sub getAiMode {
	my ($aimode) = @_;

	if (length($aimode) > 6) {
		my $t = substr($aimode, 0, 6) = ""; # Replace in a string (used here to erase)
		if ($TETRA_Verbose >= $LOGINFO) {
			print "+++ New Tetra mode: " . AiMode($t) . "\n";
		}
		my $ss;
		$ss = "tetra_mode " . $t . "\n";
#		processEvent($ss);
	}
}

####################################################
sub rmatch {
	my ($tok, $pattern) = @_;

}

####################################################
sub publishInfo {
	my ($type, $event) = @_;

}

####################################################
sub queueSds {
	my ($t_sds) = @_;

}

####################################################
sub checkSds {

}

####################################################
sub sendWelcomeSds {
	my ($tsi, $r4s) = @_;

}

####################################################
sub splitTsi {
	my ($tsi, $mcc, $mnc, $issi) = @_;

}

####################################################
# @param: a message, e.g. +CTCC: 1,1,1,0,0,1,1
# * @return: the current caller identifier
sub handleCci {
	my ($m_message) = @_;

}



sub TETRA_Rx {
	my ($Buffer, $Index) = @_;
	my $OpCode;
	my $OpArg;

	if ($TETRA_Verbose >= 1) { print color('green'), "TETRA_Rx Message.\n", color('reset');}
	if ($TETRA_Verbose >= 2) {print " " . $Buffer . "\n";}
	if ($TETRA_Verbose >= 3) {Bytes_2_HexString($Buffer);}

	handlePeiAnswer($Buffer);

	if ($TETRA_Verbose) {
		print "----------------------------------------------------------------------\n";
	}
}



##################################################################
sub peiComTimer { # Timer.
	(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime();
	if ($peiBreakCommandTimer->enabled) {
		if (time() >= $peiComTimer->timeout) {
			print color('green'), "peiComTimer event\n", color('reset');
			#print "peiComTimer Enabled " . $peiComTimer->enabled . " Timeout " . $peiComTimer->timeout . " Time " . time() . "\n";
			if ($peiComTimer->oneshot == 1) {
				$peiComTimer->enabled(0);
			}
			if ($TETRA_Verbose >= 3) {
				print "$hour:$min:$sec peiComTimer timer.\n";
				print "	Timer Timeout @{[int time - $^T]}\n";
			}
			onComTimeout();
			if ($TETRA_Verbose) {
				print "----------------------------------------------------------------------\n";
			}
			$peiComTimer->timeout(time() + $peiComTimer->interval);
		}
	}
}

##################################################################
sub peiActivityTimer { # Timer.
	(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime();
	if ($peiBreakCommandTimer->enabled) {
			if ($TETRA_Verbose >= 4) {
				print "peiActivityTimer Enabled ". $peiActivityTimer->enabled . 
					" timeout " . $peiActivityTimer->timeout . " Time " . time() .
					" interval " . $peiActivityTimer->interval . "\n";
			}
		if (time() >= $peiActivityTimer->timeout) {
			print color('green'), "peiActivityTimer event\n", color('reset');
			#print "peiActivityTimer Enabled ". $peiActivityTimer->enabled . " timeout " . $peiActivityTimer->timeout . " Time " . time() . "\n";
			if ($TETRA_Verbose >= 4) {
				print "$hour:$min:$sec peiActivityTimer timer.\n";
				print "	Timer Timeout @{[int time - $^T]}\n";
			}
			onPeiActivityTimeout();
			if ($TETRA_Verbose) {
				print "----------------------------------------------------------------------\n";
			}
			$peiActivityTimer->timeout(time() + $peiActivityTimer->interval);
		}
	}
}

##################################################################
sub peiBreakCommandTimer { # Timer.
	(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime();
	if ($peiBreakCommandTimer->enabled) {
		if (time() >= $peiBreakCommandTimer->timeout) {
			print color('green'), "peiBreakCommandTimer event\n", color('reset');
			#print "peiBreakCommandTimer Enabled " . $peiBreakCommandTimer->enabled . " Timeout " . $peiBreakCommandTimer->Timeout . " Time " . time() . "\n";
			if ($peiBreakCommandTimer->oneshot == 1) {
				$peiBreakCommandTimer->enabled(0);
			}
			if ($TETRA_Verbose >= 3) {
				print "$hour:$min:$sec peiBreakCommandTimer timer.\n";
				print "	Timer Timeout @{[int time - $^T]}\n";
			}
			onPeiBreakCommandTimeout();
			if ($TETRA_Verbose) {
				print "----------------------------------------------------------------------\n";
			}
			$peiBreakCommandTimer->timeout(time() + $peiBreakCommandTimer->interval);
		}
	}
}



##################################################################
#  #############################################################
##################################################################

####################################################
sub decodeSDS {
	my ($hexSDS) = @_;

}

####################################################
sub calcDistance {
	my ($lat1, $lon1, $lat2, $lon2) = @_;

	return;
}

####################################################
sub calcBearing {
	my ($lat1, $lon1, $lat2, $lon2) = @_;

	return;
}

####################################################
sub hex2int {
	my ($hex) = @_;
	return hex("0x" . $hex)
}

####################################################
sub getNextVal {
	my ($h) = @_;
	my @fields = split(',', $h);
	my $remainder = "";
	for (my $x = 1; $x < scalar @fields; $x++) {
		$remainder = $remainder . $fields[$x];
		if ($x < scalar @fields - 1) {$remainder = $remainder . ",";}
	}
	$_[0] = $remainder;
	return int($fields[0]);
}

####################################################
sub getNextStr {
	my ($h) = @_;
	my @fields = split(',', $h);
	my $remainder = "";
	for (my $x = 1; $x < scalar @fields; $x++) {
		$remainder = $remainder . $fields[$x];
		if ($x < scalar @fields - 1) {$remainder = $remainder . ",";}
	}
	$_[0] = $remainder;
	return $fields[0];
}

sub getPeiError {
	my ($index) = @_;

	my $Res;
	switch (int($index)) {
		case 0 {
			$Res = "0 - The MT was unable to send the data over the air (e.g. to the SwMI)";
		}
		case 1 {
			$Res = "1 - The MT can not establish a reliable communication with the TE";
		}
		case 2 {
			$Res = "2 - The PEI link of the MT is being used already";
		}
		case 3 {
			$Res = "3 - This is a general error report code which indicates that the MT supports\n the command but not in its current state. This code shall be used when no\n other code is more appropriate for the specific context";
		}
		case 4 {
			$Res = "4 - The MT does not support the command";
		}
		case 5 {
			$Res = "5 - The MT can not process any command until the PIN for the SIM is provided";
		}
		case 6 {
			$Res = "6 - Reserved";
		}
		case 7 {
			$Res = "7 - Reserved";
		}
		case 8 {
			$Res = "8 - Reserved";
		}
		case 9 {
			$Res = "9 - Reserved";
		}
		case 10 {
			$Res = "10 - The MT can not process the command due to the absence of a SIM";
		}
		case 11 {
			$Res = "11 - The SIM PIN1 is required for the MT to execute the command";
		}
		case 12 {
			$Res = "12 - MMI unblocking of the SIM PIN1 is required";
		}
		case 13 {
			$Res = "13 - The MT failed to access the SIM";
		}
		case 14 {
			$Res = "14 - The MT can not currently execute the command due to the SIM not being\n ready to proceed";
		}
		case 15 {
			$Res = "15 - The MT does not recognize this SIM";
		}
		case 16 {
			$Res = "16 - The entered PIN for the SIM is incorrect";
		}
		case 17 {
			$Res = "17 - The SIM PIN2 is required for the MT to execute the command";
		}
		case 18 {
			$Res = "18 - MMI unblocking of the SIM PIN2 is required";
		}
		case 19 {
			$Res = "19 - Reserved";
		}
		case 20 {
			$Res = "20 - The MT message stack is full";
		}
		case 21 {
			$Res = "21 - The requested message index in the message stack does not exist";
		}
		case 22 {
			$Res = "22 - The requested message index does not correspond to any message";
		}
		case 23 {
			$Res = "23 - The MT failed to store or access to its message stack";
		}
		case 24 {
			$Res = "24 - The text string associated with a status value is too long";
		}
		case 25 {
			$Res = "25 - The text string associated with a status value contains invalid characters";
		}
		case 26 {
			$Res = "26 - The <dial string> is longer than 25 digits";
		}
		case 27 {
			$Res = "27 - The <dial string> contains invalid characters";
		}
		case 28 {
			$Res = "28 - Reserved";
		}
		case 29 {
			$Res = "29 - Reserved";
		}
		case 30 {
			$Res = "30 - The MS is currently out of service and can not process the command";
		}
		case 31 {
			$Res = "31 - The MT did not receive any Layer 2 acknowledgement from the SwMI";
		}
		case 32 {
			$Res = "32 - <user data> decoding failed";
		}
		case 33 {
			$Res = "33 - At least one of the parameters is of the wrong type e.g. string instead\n of number or vice-versa";
		}
		case 34 {
			$Res = "34 - At least one of the supported parameters in the command is out of range";
		}
		case 35 {
			$Res = "35 - Syntax error. The syntax of the command is incorrect e.g. mandatory\n parameters are missing or are exceeding Data received without command";
		}
		case 36 {
			$Res = "36 - The MT received <user data> without AT+CMGS= ...<CR>";
		}
		case 37 {
			$Res = "37 - AT+CMGS command received, but timeout expired waiting for <userdata>";
		}
		case 38 {
			$Res = "38 - The TE has already registered the Protocol Identifier with the MT";
		}
		case 39 {
			$Res = "39 - Registration table in SDS-TL is full. The MT can no longer register\n a new Protocol Identifier until a registered Protocol identifier is\n deregistered";
		}
		case 40 {
			$Res = "40 - The MT supports the requested service but not while it is in DMO";
		}
		case 41 {
			$Res = "41 - The MT is in Transmit inhibit mode and is not able to process the\n command in this state";
		}
		case 42 {
			$Res = "42 - The MT is involved in a signalling activity and is not able to process\n the available command until the current transaction ends. In V+D,\n the signalling activity could be e.g. group attachment, group report, SDS\n processing, processing of DGNA, registration, authentication or any\n transaction requiring a response from the MS or the SwMI. In DMO, the\n signalling activity could be e.g. Call or SDS processing.";
		}
		case 43 {
			$Res = "43 - The MT supports the requested service but not while it is in V+D";
		}
		case 44 {
			$Res = "44 - The MT supports handling of unknown parameters";
		}
		case 45 {
			$Res = "45 - Reserved";
		}
	}
	return $Res;
}

####################################################
sub getISSI {
	my ($tsi) = @_;

}

####################################################
sub splitTsi {
	my ($tsi, $mcc, $mnc, $issi) = @_;

	my $ret = 0;
	my $len = length($tsi);

	if ($len < 9) {
		$issi = int($tsi);
		$mcc = 0;
		$mnc = 0;
		$ret = 1;
	} else {
		$issi = int(substr($tsi, $len - 8, 8));
		my $t = substr($tsi, 0, $len - 8);

		if (length($t) == 7) {
			$mcc = int(substr($t, 0, 3));
			$mnc = int(substr($t, 3, 4));
			$ret = 1;
		} elsif (length($t) == 8) {
			$mcc = int(substr($t, 0, 3));
			$mnc = int(substr($t, 3, 5));
			$ret = 1;
		}
		elsif (length($t) == 9) {
			$mcc = int(substr($t, 0, 4));
			$mnc = int(substr($t, 4, 5));
			$ret = 1;
		} else {
			$ret = 0;
		}
	}

	$_[1] = $mcc;
	$_[2] = $mnc;
	$_[3] = $issi;
	return $ret;
}

####################################################
sub setSql {
	my ($is_open) = @_;

}


























sub m_cmds {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return('');
		}
		case 0x01 {
			return("AT+CTOM:6,0");
		}
		case 0x02 {
			return("AT+CTSP:1,3,131");
		}
		case 0x03 {
			return("AT+CTSP:1,3,130");
		}
		case 0x04 {
			return("AT+CTSP:1,3,138");
		}
		case 0x05 {
			return("AT+CTSP:1,2,20");
		}
		case 0x06 {
			return("AT+CTSP:2,0,0");
		}
		case 0x07 {
			return("+CTSP:1,3,24");
		}
		case 0x08 {
			return("+CTSP:1,3,25");
		}
		case 0x09 {
			return("+CTSP:1,3,3");
		}
		case 0x0A {
			return("+CTSP:1,3,10");
		}
		case 0x0B {
			return("+CTSP:1,1,11");
		}
		case 0x0C {
			return("+CTSDC:0,0,0,1,1,0,1,1,0,0");
		}
		case 0x0D {
			return("+CNUMF?");
		}
	}
}

sub TxGrant {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - Transmission granted");
		}
		case 0x01 {
			return("1 - Transmission not granted");
		}
		case 0x02 {
			return("2 - Transmission queued");
		}
		case 0x03 {
			return("3 - Transmission granted to another");
		}
	}
}

sub CallStatus {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - Call progressing");
		}
		case 0x01 {
			return("1 - Call queued");
		}
		case 0x02 {
			return("2 - Called party paged");
		}
		case 0x03 {
			return("3 - Call continue");
		}
		case 0x04 {
			return("4 - Hang time expired");
		}
	}
}

sub CalledPartyIdentityType {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - SSI");
		}
		case 0x01 {
			return("1 - TSI");
		}
		case 0x02 {
			return("2 - SNA (V+D only)");
		}
		case 0x03 {
			return("3 - PABX external subscriber number (V+D or DMO if via a gateway)");
		}
		case 0x04 {
			return("4 - PSTN external subscriber number (V+D or DMO if via a gateway)");
		}
		case 0x05 {
			return("5 - Extended TSI");
		}
	}
}

sub AiMode {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - V+D (trunked mode operation)");
		}
		case 0x00 {
			return("1 - DMO");
		}
		case 0x00 {
			return("2 - V+D with dual watch of DMO");
		}
		case 0x00 {
			return("3 - DMO with dual watch of V+D");
		}
		case 0x00 {
			return("4 - V+D and DMO (used in conjunction CTSP command)");
		}
		case 0x00 {
			return("5 - NN");
		}
		case 0x00 {
			return("6 - DMO Repeater mode");
		}
	}
}

sub TxDemandPriority {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - Low");
		}
		case 0x00 {
			return("1 - High");
		}
		case 0x00 {
			return("2 - Pre-emptive");
		}
		case 0x00 {
			return("3 - Emergency");
		}
	}
}

sub TransientComType {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - Voice + Data");
		}
		case 0x01 {
			return("1 - DMO-Direct MS-MS");
		}
		case 0x02 {
			return("2 - DMO-Via DM-REP");
		}
		case 0x03 {
			return("3 - DMO-Via DM-GATE");
		}
		case 0x04 {
			return("4 - DMO-Via DM-REP/GATE");
		}
		case 0x05 {
			return("5 - Reserved");
		}
		case 0x06 {
			return("6 - Direct MS-MS, but maintain gateway registration");
		}
	}
}

sub RegStat {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - Registering or searching a network, one or more networks are available");
		}
		case 0x01 {
			return("1 - Registered, home network");
		}
		case 0x02 {
			return("2 - Not registered, no network currently available");
		}
		case 0x03 {
			return("3 - System reject, no other network available");
		}
		case 0x04 {
			return("4 - Unknown");
		}
		case 0x05 {
			return("5 - Registered, visited network");
		}
	}
}

sub AiService {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - TETRA speech");
		}
		case 0x01 {
			return("1 - 7,2 kbit/s unprotected data");
		}
		case 0x02 {
			return("2 - Low protection 4,8 kbit/s short interleaving depth = 1");
		}
		case 0x03 {
			return("3 - Low protection 4,8 kbit/s medium interleaving depth = 4");
		}
		case 0x04 {
			return("4 - Low protection 4,8 kbit/s long interleaving depth = 8");
		}
		case 0x05 {
			return("5 - High protection 2,4 kbit/s short interleaving depth = 1");
		}
		case 0x06 {
			return("6 - High protection 2,4 kbit/s medium interleaving depth = 4");
		}
		case 0x07 {
			return("7 - High protection 2,4 kbit/s high interleaving depth = 8");
		}
		case 0x08 {
			return("8 - Packet Data (V+D only)");
		}
		case 0x09 {
			return("9 - SDS type 1 (16 bits)");
		}
		case 10 {
			return("10 - SDS type 2 (32 bits)");
		}
		case 11 {
			return("11 - SDS type 3 (64 bits)");
		}
		case 12 {
			return("12 - SDS type 4 (0 - 2 047 bits)");
		}
		case 13 {
			return("13 - Status (16 bits, some values are reserved in EN 300 392-2 [3])");
		}
	}
}

sub DisconnectCause {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - Not defined or unknown");
		}
		case 0x01 {
			return("1 - User request");
		}
		case 0x02 {
			return("2 - Called party busy");
		}
		case 0x03 {
			return("3 - Called party not reachable");
		}
		case 0x04 {
			return("4 - Called party does not support encryption");
		}
		case 0x05 {
			return("5 - Network congestion");
		}
		case 0x06 {
			return("6 - Not allowed traffic");
		}
		case 0x07 {
			return("7 - Incompatible traffic");
		}
		case 0x08 {
			return("8 - Service not available");
		}
		case 0x09 {
			return("9 - Pre-emption");
		}
		case 10 {
			return("10 - Invalid call identifier");
		}
		case 11 {
			return("11 - Called party rejection");
		}
		case 12 {
			return("12 - No idle CC entity");
		}
		case 13 {
			return("13 - Timer expiry");
		}
		case 14 {
			return("14 - SwMI disconnect");
		}
		case 15 {
			return("15 - No acknowledgement");
		}
		case 16 {
			return("16 - Unknown TETRA identity");
		}
		case 17 {
			return("17 - Supplementary Service dependent");
		}
		case 18 {
			return("18 - Unknown external subscriber number");
		}
		case 19 {
			return("19 - Call restoration failed");
		}
		case 20 {
			return("20 - Called party requires encryption");
		}
		case 21 {
			return("21 - Concurrent set-up not supported");
		}
		case 22 {
			return("22 - Called party is under the same DM-GATE as the calling party");
		}
		case 23 {
			return("23 - Reserved");
		}
		case 24 {
			return("24 - Reserved");
		}
		case 25 {
			return("25 - Reserved");
		}
		case 26 {
			return("26 - Reserved");
		}
		case 27 {
			return("27 - Reserved");
		}
		case 28 {
			return("28 - Reserved");
		}
		case 29 {
			return("29 - Reserved");
		}
		case 30 {
			return("30 - Reserved");
		}
		case 31 {
			return("31 - Called party offered unacceptable service");
		}
		case 32 {
			return("32 - Pre-emption by late entering gateway");
		}
		case 33 {
			return("33 - Link to DM-REP not established or failed");
		}
		case 34 {
			return("34 - Link to gateway failed");
		}
		case 35 {
			return("35 - Call rejected by gateway");
		}
		case 36 {
			return("36 - V+D call set-up failure");
		}
		case 37 {
			return("37 - V+D resource lost or call timer expired");
		}
		case 38 {
			return("38 - Transmit authorization lost");
		}
		case 39 {
			return("39 - Channel has become occupied by other users");
		}
		case 40 {
			return("40 - Security parameter mismatch");
		}
	}
}

sub DmCommunicationType {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return( "0 - Any, MT decides");
		}
		case 0x01 {
			return( "1 - Direct MS-MS");
		}
		case 0x02 {
			return( "2 - Via DM-REP");
		}
		case 0x03 {
			return( "3 - Via DM-GATE");
		}
		case 0x04 {
			return( "4 - Via DM-REP/GATE");
		}
		case 0x05 {
			return( "5 - Reserved");
		}
		case 0x06 {
			return( "6 - Direct MS-MS, but maintain gateway registration");
		}
	}
}

sub NumType {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return( "0 - Individual (ISSI or ITSI)");
		}
		case 0x01 {
			return( "1 - Group (GSSI or GTSI)");
		}
		case 0x02 {
			return( "2 - PSTN Gateway (ISSI or ITSI)");
		}
		case 0x03 {
			return( "3 - PABX Gateway (ISSI or ITSI)");
		}
		case 0x04 {
			return( "4 - Service Centre (ISSI or ITSI)");
		}
		case 0x05 {
			return( "5 - Service Centre (E.164 number)");
		}
		case 0x06 {
			return( "6 - Individual (extended TSI)");
		}
		case 0x07 {
			return( "7 - Group (extended TSI)");
		}
	}
}

sub ReasonForSending {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - Subscriber unit is powered ON");
		}
		case 0x01 {
			return("1 - Subscriber unit is powered OFF");
		}
		case 0x02 {
			return("2 - Emergency condition is detected");
		}
		case 0x03 {
			return("3 - Push-to-talk condition is detected");
		}
		case 0x04 {
			return("4 - Status");
		}
		case 0x05 {
			return("5 - Transmit inhibit mode ON");
		}
		case 0x06 {
			return("6 - Transmit inhibit mode OFF");
		}
		case 0x07 {
			return("7 - System access (TMO ON)");
		}
		case 0x08 {
			return("8 - DMO ON");
		}
		case 0x09 {
			return("9 - Enter service (after being out of service)");
		}
		case 10 {
			return("10 - Service loss");
		}
		case 11 {
			return("11 - Cell reselection or change of serving cell");
		}
		case 12 {
			return("12 - Low battery");
		}
		case 13 {
			return("13 - Subscriber unit is connected to a car kit");
		}
		case 14 {
			return("14 - Subscriber unit is disconnected from a car kit");
		}
		case 15 {
			return("15 - Subscriber unit asks for transfer initialization configuration");
		}
		case 16 {
			return("16 - Arrival at destination");
		}
		case 17 {
			return("17 - Arrival at a defined location");
		}
		case 18 {
			return("18 - Approaching a defined location");
		}
		case 19 {
			return("19 - SDS type-1 entered");
		}
		case 20 {
			return("20 - User application initiated");
		}
		case 21 {
			return("21 - Reserved");
		}
	}
}

sub GroupType {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - None");
		}
		case 0x01 {
			return("1 - Select");
		}
		case 0x02 {
			return("2 - Scan priority 1");
		}
		case 0x03 {
			return("3 - Scan priority 2");
		}
		case 0x04 {
			return("4 - Scan priority 3");
		}
		case 0x05 {
			return("5 - Scan priority 4");
		}
		case 0x06 {
			return("6 - Scan priority 5");
		}
		case 0x07 {
			return("7 - Scan priority 6");
		}
	}
}


sub sdsStatus {
	my ($index) = @_;
	switch ($index) {
		case 0x00 {
			return("0 - Incoming message stored and unread");
		}
		case 0x01 {
			return("1 - Incoming message stored and read");
		}
		case 0x02 {
			return("2 - Outgoing message stored and unsent");
		}
		case 0x03 {
			return("3 - Outgoing message stored and sent");
		}
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

sub PTT_Interrupt_Handler {
	print color('yellow'), "PTT Interrupt Handler.\n", color('reset');
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
				}
				case ord('c') { # 'c'
				}
				case ord('E') {
				}
				case ord('e') {
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
					transmitterStateChange(1);
				}
				case ord('p') { # 'p'
					transmitterStateChange(0);
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
					$TETRA_Verbose = 1;
				}
				case ord('t') { # 't'
					$TETRA_Verbose = 0;
				}
				case ord('w') { # 'w'
					handleCnumf("+CNUMF: 6,09011638300023401");
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



#################################################################################
# Main Loop #####################################################################
#################################################################################
sub MainLoop {
	while ($Run) {
		my $Scan = 0;
		(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime();

		initPei();
		Read_Serial(); # Serial Port Receiver when Mode == 0.

		peiComTimer();
		peiActivityTimer();
		peiBreakCommandTimer();

		nanosleep(010000000); # 2 ms

		
#		if ($peirequest == $INIT_COMPLETE) {$Run = 0;}

		APRS_Timer(); # APRS-IS Timer to send position/objects to APRS-IS.
		HotKeys(); # Keystrokes events.
		if ($Verbose >= 5) { print "Looping the right way.\n"; }
		#my $NumberOfTalkGroups = scalar keys %TG;
		#print "Total number of links is: $NumberOfTalkGroups\n\n";
	}
}

