package TetraLogic;
# TetraLogic.pm

# @file TetraLogic.pm
# @brief Contains a Tetra logic SvxLink core implementation
# @author Juan Carlos Pérez KM4NNO / XE1F
# Based on the work done by Tobias Blomberg / SM0SVX & Adi Bier / DL1HRC
# @date March 10, 2022.
# \verbatim
# SvxLink - A Multi Purpose Voice Services System for Ham Radio Use
# Copyright (C) 2003-2021 Tobias Blomberg / SM0SVX
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# \endverbatim

use strict;
use warnings;
use Switch;
use Device::SerialPort;
use Term::ANSIColor;
use Class::Struct;
use Time::HiRes qw(nanosleep);
use RPi::Pin;
use RPi::Const qw(:all);

use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
use TetraLib;


# ****************************************************************************
# *
# * TetraLogic.h
# *
# *****************************************************************************

my $mute_rx_on_tx = 1;
my $mute_tx_on_rx = 1;
my $rgr_sound_always = 0;
my $mcc;
my $mnc;
my $issi;
my $gssi;
my $port;
my $baudrate;
my $initstr;

my $SerialPort; # pei
my $sds_pty;
#my $dapnetclient;

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

my @sdsQueue;

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

my $dmo_rep_gw = DmoRpt->new();

my @sds_on_activity;
my $sds_to_command;

my $peistate;
my $peistream = '';
my $talkgroup_up = 0;

use constant IDLE => 0;
use constant CHECK_AT => 1;
use constant INIT_ => 2;
use constant IGNORE_ERRORS => 3;
use constant INIT_COMPLETE => 4;
use constant WAIT => 5;
use constant AT_CMD_WAIT => 6;

my $peirequest = TetraLogic::AT_CMD_WAIT;

# AI Service;
# This parameter is used to determine the type of service to be used;
# in air interface call set up signalling. The services are all;
# defined in EN 300 392-2 [3] or EN 300 396-3 [25].;
use constant TETRA_SPEECH => 0;
use constant UNPROTECTED_DATA => 1;
use constant PACKET_DATA => 8;
use constant SDS_TYPE1 => 9;
use constant SDS_TYPE2 => 10;
use constant SDS_TYPE3 => 11;
use constant SDS_TYPE4 => 12;
use constant STATUS_SDS => 13;

# direction of Sds;
use constant OUTGOING => 0;
use constant INCOMING => 1;

# type of Sds;
use constant STATE => 0;
use constant TEXT => 1;
use constant LIP_SHORT => 2;
use constant COMPLEX_SDS_TL => 3;
use constant RAW => 4;

# Sds sent state;
use constant SDS_SEND_OK => 4;
use constant SDS_SEND_FAILED => 5;

my $sds_when_dmo_on;
my $sds_when_dmo_off;
my $sds_when_proximity;

struct( Timer => [
	enabled => '$',
	oneshot => '$',
	interval => '$',
	timeout => '$',
]);

my $peiComTimer = Timer->new(interval=>2, oneshot=>1, enabled=>0, timeout=>time() + 2);
my $peiActivityTimer = Timer->new(interval=>10, oneshot=>1, enabled=>1, timeout=>time());
my $peiBreakCommandTimer = Timer->new(interval=>3, oneshot=>1, enabled=>0, timeout=>time() + 3);

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

my $call = Call->new();

struct( pSds => [
	sdstype => '$',
	aiservice => '$',
	fromtsi => '$',
	totsi => '$',
	last_activity => '$',
]);

my $pSDS = pSds->new();

my $state_sds;
my $pending_sdsid;
my $proximity_warning = 3.1;
my $time_between_sds = 3600;
my $own_lat;
my $own_lon;
my $endCmd = '';
my $new_sds = 0;
my $last_distance;
my $inTransmission = 0;
my $cmgs_received;
my $share_userinfo;
my $current_cci = 0;
my $dmcc;
my $dmnc;
my $infosds;



# ****************************************************************************
# *
# * TetraLogic CPP		Defines & typedefs
# *
# *****************************************************************************

use constant OK => 0;
use constant ERROR => 1;
use constant CALL_BEGIN => 3;
use constant GROUPCALL_END => 4;

use constant SDS => 6;
use constant TEXT_SDS => 7;
use constant CNUMF => 8;
use constant CALL_CONNECT => 9;
use constant TRANSMISSION_END => 10;
use constant CALL_RELEASED => 11;
use constant LIP_SDS => 12;
use constant REGISTER_TSI => 13;
use constant STATE_SDS => 14;
use constant OP_MODE => 15;
use constant TRANSMISSION_GRANT => 16;
use constant TX_DEMAND => 17;
use constant TX_WAIT => 18;
use constant TX_INTERRUPT => 19;
use constant SIMPLE_LIP_SDS => 20;
use constant COMPLEX_SDS => 21;
use constant MS_CNUM => 22;
use constant WAP_PROTOCOL => 23;
use constant SIMPLE_TEXT_SDS => 24;
use constant ACK_SDS => 25;
use constant CMGS => 26;
use constant CONCAT_SDS => 27;
use constant CTGS => 28;
use constant CTDGR => 29;
use constant CLVL => 30;
use constant OTAK => 31;
use constant WAP_MESSAGE => 32;
use constant LOCATION_SYSTEM_TSDU => 33;

use constant DMO_OFF => 7;
use constant DMO_ON => 8;

use constant INVALID => 254;
use constant TIMEOUT => 255;

use constant LOGERROR => 0;
use constant LOGWARN =>1;
use constant LOGINFO => 2;
use constant LOGDEBUG => 3;
use constant LOGDEBUG1 => 4;
use constant LOGDEBUG2 => 5;
use constant LOGDEBUG3 => 6;

use constant TETRA_LOGIC_VERSION => '19122021';



# no debugging by default
my $debug = 0;
my $AT_Buffer = ''; # Clear AT Rx buffer.
my $InitCounter = 0;
my $Node_Number;


$gssi = 1;
$initstr = '';
my $pei = '';

$proximity_warning = 3.1;
$time_between_sds = 3600;
$cmgs_received = 1;
$share_userinfo = 1;


my $last_sdsinstance = '';
my $tetra_modem_sql = 0;


my $RadioID_URL = 'https://database.radioid.net/api/dmr/';



my $caller = Call->new(); # allocate an empty Person struct

#$caller->mcc(901);			# set its name field
#$caller->mnc(16383);		# set its age field
#$caller->issi(33401010);	# set its peers field
#print "caller " . $caller->mcc . "\n";



my $PTT_IN_GPIO; # Red
my $SQL_OUT_GPIO; # Yellow
my $PTT_IN_PIN;
my $SQL_OUT_PIN;

my $PTT_in_old = 0;






print "----------------------------------------------------------------------\n";



# ****************************************************************************
# *
# * Local class definitions
# *
# ****************************************************************************

sub new {
	if ($debug) {print color('cyan'), "TetraLogic::new\n", color('reset');}
	my $class = shift;
	my $self = bless { @_ }, $class;

	$self->{'initialized'} = 0;

	my %defaults = (
		'debug' => $debug,
		'Baudrate' => 9600,
	);

	$self->{'debug'} = ( $self->{'config'}->{'debug'} );

	my $cfg = Config::IniFiles->new( -file => "config.ini");

	my $latitude = $cfg->val('APRS', 'Latitude');
	my $longitude = $cfg->val('APRS', 'Longitude');
	$own_lat = getDecimalDegree($latitude);
	$own_lon = getDecimalDegree($longitude);

	$mcc = $cfg->val('TETRA', 'MCC');
	$mnc = $cfg->val('TETRA', 'MNC');
	$issi = $cfg->val('TETRA', 'ISSI');
	$gssi = $cfg->val('TETRA', 'GSSI');
	$infosds = $cfg->val('TETRA', 'INFO_SDS');
	$debug = $cfg->val('TETRA', 'DEBUG');
	$port = $cfg->val('TETRA', 'PORT');
	$baudrate = $cfg->val('TETRA', 'BAUD');
	$sds_pty = $cfg->val('TETRA', 'SDS_PTY');
	$Node_Number = $cfg->val('Settings', 'Node_Number');
	print "	mcc = $mcc\n";
	print "	mnc = $mnc\n";
	print "	issi = $issi\n";
	print "	gssi = $gssi\n";
	print "	infosds = $infosds\n";
	print "	debug = $debug\n";
	print "	port = $port\n";
	print "	baudrate = $baudrate\n";
	print "	sds_pty = $sds_pty\n";
	print "	Node_Number = $Node_Number\n";

# Get user_section line 361

# Get sds commands line 511
	my $sds_to_cmd;
	my $isds;
	
	$time_between_sds = $cfg->val('TETRA', 'TIME_BETWEEN_SDS');

	# Init Seial Port
	print color('green'), "Init Serial Port\n", color('reset');
	my $OS = $^O; # Detect Target OS.
	# For Mac:
	if ($OS eq "darwin") {
		$SerialPort = Device::SerialPort->new('/dev/tty.usbserial') || die "Cannot Init Serial Port : $!\n";
	}
	# For Linux:
	if ($OS eq "linux") {
		$SerialPort = Device::SerialPort->new('/dev/ttyUSB0') || die "Cannot Init Serial Port : $!\n";
	}
	$SerialPort->baudrate($baudrate);
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

	my $cmd = '';
	sendPei($cmd);

	$peirequest = AT_CMD_WAIT;
#	initPei();

	print color('green'), "Init TetraLogic::GPIO\n", color('reset');
	$PTT_IN_GPIO = $cfg->val('GPIO', 'PTT_IN_GPIO'); # Red
	$SQL_OUT_GPIO = $cfg->val('GPIO', 'SQL_OUT_GPIO'); # Yellow
	print "	PTT_IN_GPIO = $PTT_IN_GPIO\n";
	print "	SQL_OUT_GPIO = $SQL_OUT_GPIO\n";
	$PTT_IN_PIN = RPi::Pin->new($PTT_IN_GPIO, "Red");
	$SQL_OUT_PIN = RPi::Pin->new($SQL_OUT_GPIO, "Yellow");

	# This use the BCM pin numbering scheme.
	# Valid GPIOs are: 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27.
	# GPIO 2, 3 Aleternate for I2C.
	# GPIO 14, 15 alternate for USART.
	$PTT_IN_PIN->mode(INPUT); # Red
	$SQL_OUT_PIN->mode(OUTPUT); # Yellow

	$SQL_OUT_PIN->write(HIGH); # Yellow

	$PTT_IN_PIN->pull(PUD_UP); # Red

	$PTT_in_old = 0;


	# returning object from constructor
	return $self;
}

sub DESTROY {
	my $self = shift;
	$SerialPort->close || die "Failed to close SerialPort.\n";


	print "DESTROYED\n";

}



##################################################################
# Serial #########################################################
##################################################################
sub Read_Serial { # Read the serial port, look for 0x7E characters and extract data between them.
#	my $NumChars;
#	my $SerialBuffer;
	my ($NumChars, $SerialBuffer) = $SerialPort->read(255);
	if ($NumChars >= 1 ){ #Perl data Arrival test.
		#Bytes_2_HexString($SerialBuffer);
		for (my $x = 0; $x <= $NumChars; $x++) {
			if (ord(substr($SerialBuffer, $x, 1)) == 0x0D) {
				if (length($AT_Buffer) > 0) {
					TETRA_Rx($AT_Buffer);
					if ($debug >= 3) {
						print color('green'), "Serial_Rx\n", color('reset');
						#print "\tSerial Rx len() = " . length($AT_Buffer) . "\n";
						print "\tRx line = " . $AT_Buffer . "\n";
						}
					if ($debug >= 4) {Bytes_2_HexString($AT_Buffer);}
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
			sendPei($cmd);
		}
	} else {
		my $cmd = 'AT+CUTXC=' . $current_cci;
		sendPei($cmd);
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

#	$tetra_modem_sql->setSql($is_open);
	setSql($is_open);
	#rx().setSql(is_open);
	#Logic::squelchOpen(is_open); # GPIO19 = SQL

}



sub TETRA_Rx {
	my ($Buffer, $Index) = @_;
	my $OpCode;
	my $OpArg;

	if ($debug) { print color('green'), "TETRA_Rx Message.\n", color('reset');}
	handlePeiAnswer($Buffer);

	if ($debug) {
		print "----------------------------------------------------------------------\n";
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
	if ($peirequest == AT_CMD_WAIT) {
		$peiBreakCommandTimer->timeout(time() + $peiBreakCommandTimer->interval);
		$peiBreakCommandTimer->enabled(1);
	}
	if ($InitCounter < 14) {
		switch ($InitCounter) {
			case 0 {
				$cmd = '';
				sendPei($cmd);
				nanosleep(002000000); # 2 ms
				$InitCounter++;
			}
			case 1 {
				$cmd = 'AT';
				sendPei($cmd);
				$InitCounter++;
			}
			case 2 {
				$cmd = 'AT+CTOM=6,0';
				sendPei($cmd);
				$InitCounter++;
			}
			case 3 {
				$cmd = 'AT+CTSP=1,3,131';
				sendPei($cmd);
				$InitCounter++;
			}
			case 4 {
				$cmd = 'AT+CTSP=1,3,130';
				sendPei($cmd);
				$InitCounter++;
			}
			case 5 {
				$cmd = 'AT+CTSP=1,3,138';
				sendPei($cmd);
				$InitCounter++;
			}
			case 6 {
				$cmd = 'AT+CTSP=1,2,20';
				sendPei($cmd);
				$InitCounter++;
			}
			case 7 {
				$cmd = 'AT+CTSP=2,0,0';
				sendPei($cmd);
				$InitCounter++;
			}
			case 8 {
				$cmd = 'AT+CTSP=1,3,24';
				sendPei($cmd);
				$InitCounter++;
			}
			case 9 {
				$cmd = 'AT+CTSP=1,3,25';
				sendPei($cmd);
				$InitCounter++;
			}
			case 10 {
				$cmd = 'AT+CTSP=1,3,3';
				sendPei($cmd);;
				$InitCounter++;
			}
			case 11 {
				$cmd = 'AT+CTSP=1,3,10';
				sendPei($cmd);
				$InitCounter++;
			}
			case 12 {
				$cmd = 'AT+CTSP=1,1,11';
				sendPei($cmd);
				$InitCounter++;
			}
			case 13 {
				$cmd = "AT+CTSDC=0,0,0,1,1,0,1,1,0,0";
				sendPei($cmd);
				$InitCounter++;
#print "Bla $InitCounter\n";
			}
		}
		print "***** $peirequest **********************************\n";
	} elsif ($peirequest == INIT_) {
		$cmd = "AT+CNUMF?"; # get the MCC,MNC,ISSI from MS
		sendPei($cmd);
		my $ss = "pei_init_finished\n";
		print $ss;
		sendUserInfo(); # send userinfo to reflector
		$peirequest = INIT_COMPLETE;
		print color('magenta'), "TETRA Pei Init Complete\n", color('reset');
	}
}

####################################################
sub sendUserInfo {

# To Do

	return;
}

####################################################
sub handlePeiAnswer {
	my ($m_message) = @_;

	if ($debug >= LOGINFO) {
		print "From PEI:" . $m_message . "\n";
		#print " length(m_message)" + str(length(m_message));
	}
	
	my $response = handleMessage($m_message);

	switch ($response) {
		case OK { # OK
			$peistate = OK;
			if ($new_sds and !$inTransmission) {
				checkSds();
			}
		}
		case ERROR { # ERROR
			$peistate = ERROR;
		if ((length($m_message) > 11) and ($debug >= LOGINFO)) {
				my $Error = substr($m_message, 11);
				print color('yellow'), " +CME ERROR: " . getPeiError($Error) . "\n", color('reset');
			}
		}
		case CNUMF { # CNUMF
			handleCnumf($m_message);
		}
		case CALL_BEGIN { # CALL_BEGIN
			handleCallBegin($m_message);
		}
		case TRANSMISSION_END { # TRANSMISSION_END
			handleTransmissionEnd($m_message);
		}
		case CALL_RELEASED { # CALL_RELEASED
			handleCallReleased($m_message);
		}
		case SDS { # SDS
			handleSds($m_message);
		}
		case ACK_SDS { # ACK_SDS
			print "ACK_SDS";
		}
		case TEXT_SDS { # TEXT_SDS
			handleSdsMsg($m_message);
		}
		case SIMPLE_TEXT_SDS { # SIMPLE_TEXT_SDS
		handleSdsMsg($m_message);
		}
		case STATE_SDS { # STATE_SDS
			handleSdsMsg($m_message);
		}
		case COMPLEX_SDS { # COMPLEX_SDS
			handleSdsMsg($m_message);
		}
		case CONCAT_SDS { # CONCAT_SDS
			handleSdsMsg($m_message);
		}
		case LIP_SDS { # LIP_SDS
			handleSdsMsg($m_message);
		}
		case CMGS { # CMGS
			# sds state send be MS
			handleCmgs($m_message);
		}
		case TX_DEMAND { # TX_DEMAND
			# NOP
		}
		case TRANSMISSION_GRANT { # TRANSMISSION_GRANT
			handleTxGrant($m_message);
		}
		case CALL_CONNECT { # CALL_CONNECT
			$current_cci = handleCci($m_message);
		}
		case OP_MODE { # OP_MODE
			getAiMode($m_message);
		}
		case CTGS { # CTGS
			handleCtgs($m_message);
		}
		case CTDGR { # CTDGR
			handleCtdgr($m_message);
		}
		case CLVL { # CLVL
			handleClvl($m_message);
		}
		case INVALID { # INVALID
			if ($debug >= LOGWARN) {
				warn color('yellow'), "+++ Pei answer not known, ignoring.", color('reset');
			}
		}
		else {
			if ($debug >= LOGWARN) {
				warn color('yellow'), "Uknown Command m_message = " . $m_message . "\n";
				print " Len(m_message) = " . length($m_message) . "\n", color('reset');
			}
		}
	}
	if (($peirequest == INIT_) and (($response == OK) or ($response == ERROR))) {
		initPei();
	}
}

####################################################
sub initGroupCall {
	my ($gc_gssi) = @_;
	$inTransmission = 1;
	my $cmd = "AT+CTSDC=0,0,0,1,1,0,1,1,0,0,0";
	sendPei($cmd);

	$cmd = "ATD";
	$cmd = $cmd. $gc_gssi;
	sendPei($cmd);
	
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
#		if ($debug >= LOGWARN) {
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
		my $o_mcc;
		my $o_mnc;
		my $o_issi;
		#splitTsi($o_tsi, $t_ci->o_mcc, $t_ci->o_mnc, $t_ci->o_issi);
		splitTsi($o_tsi, $o_mcc, $o_mnc, $o_issi);
		$t_ci->o_mcc($o_mcc);
		$t_ci->o_mnc($o_mnc);
		$t_ci->o_issi($o_issi);
	}

	$t_ci->hook(getNextVal($h));
	$t_ci->simplex(getNextVal($h));
	$t_ci->e2eencryption(getNextVal($h));
	$t_ci->commstype(getNextVal($h));
	$t_ci->codec(getNextVal($h));
	$t_ci->dest_cpit(getNextVal($h));

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
		my $d_mcc;
		my $d_mnc;
		my $d_issi;
		#splitTsi($d_tsi, $t_ci->d_mcc, $t_ci->d_mnc, $t_ci->d_issi);
		splitTsi($d_tsi, $d_mcc, $d_mnc, $d_issi);
		$t_ci->d_mcc($d_mcc);
		$t_ci->d_mnc($d_mnc);
		$t_ci->d_issi($d_issi);
	}

	$t_ci->prio(int($h));

	# store call specific data into a Callinfo struct
	$callinfo[$t_ci->instance] = $t_ci;

	# check if the user is stored? no -> default
	#std::map<std::string, User>::iterator iu = userdata.find(o_tsi);
	my $ui;
	foreach $ui(@userdata) {
		if ($ui == $o_tsi) {
			last;
		}
	}
	#if ($iu == userdata.end()) {
	if ($ui == scalar(@userdata)) {
		my $t_sds = Sds->new();
		$t_sds->nroftries(0);
		$t_sds->direction(OUTGOING);
		$t_sds->message($infosds);
		$t_sds->tsi($o_tsi);
		$t_sds->type(TEXT);
		firstContact($t_sds);
		return;
	}

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
	my ($sds) = @_;

	substr($sds, 0, 9) = ""; # Replace in a string (used here to erase)

	# store header of sds for further handling
	$pSDS->aiservice(getNextVal($sds));			# type of SDS (TypeOfService 0-12)
	$pSDS->fromtsi(getTSI(getNextStr($sds)));	# sender Tsi (23404)
	getNextVal($sds);							# (0)
	$pSDS->totsi(getTSI(getNextStr($sds)));		# destination Issi
	getNextVal($sds);							# (0)
	getNextVal($sds);							# Sds length (112)
	$pSDS->last_activity(time());
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
#		$tsds->direction(OUTGOING);
#		$tsds->message($infosds);
#		$tsds->type(TEXT);
#		$tsds->remark("Welcome Sds to a new user");
#		if ($debug >= LOGINFO) {
#			print "Sending info Sds to new user " . $tsds->tsi . " \"" .
#				$infosds . "\"\n";
#		}
		queueSds($tsds);
#	}
}

####################################################
# Handle the sds message
# Example:
# (+CTSDSR: 12,23404,0,23401,0,112)
# 82040801476A61746A616A676A61
sub handleSdsMsg {
	my ($sds) = @_;

	my $t_sds = Sds->new();
	$t_sds->nroftries(0);
	my $ss = '';
	my $sstcl;
	my $sds_txt;
	my $m_aprsinfo;
#	std::map<unsigned int, string>::iterator it;
	my $lipinfo = LipInfo->new();
#	Json::Value event(Json::arrayValue);
#	Json::Value sdsinfo(Json::objectValue);

	$t_sds->tos($pSDS->last_activity);			# last activity
	$t_sds->direction(INCOMING);	# 1 = received
	$t_sds->tsi($pSDS->fromtsi);

#	std::map<std::string, User>::iterator iu = userdata.find(t_sds.tsi);
#	if (iu == userdata.end())
#	{
#		firstContact(t_sds);
#	}

	# update last activity of sender
#	userdata[t_sds.tsi].last_activity = time(NULL);

	my $m_sdstype = handleMessage($sds);
	$t_sds->type($m_sdstype);

	my $isds;
	
	switch($m_sdstype) {
		case LIP_SDS { # LIP_SDS
			print color('green'), "LIP_SDS\n" , color('reset');
			handleLipSds($sds, $lipinfo);

			print "Lat = " . dec2nmea_lat($lipinfo->latitude) . "\n";
			print "Long = " . dec2nmea_lon($lipinfo->longitude) . "\n";

#			$m_aprsinfo = "!" . dec2nmea_lat($lipinfo->latitude) .
#				iu->second.aprs_sym << dec2nmea_lon(lipinfo.longitude)
#				iu->second.aprs_tab << iu->second.name << ", "
#				iu->second.comment;
#			$ss << "lip_sds_received " << t_sds.tsi << " " 
#				 << lipinfo.latitude << " " << lipinfo.longitude;
#			userdata[t_sds.tsi].lat = lipinfo.latitude;
#			userdata[t_sds.tsi].lon = lipinfo.longitude;
#			userdata[t_sds.tsi].reasonforsending = lipinfo.reasonforsending;

			# Power-On -> send welcome sds to a new station
			sendWelcomeSds($t_sds->tsi, $lipinfo->reasonforsending);

			# send an info sds to all other stations that somebody is in vicinity
			# sendInfoSds(tsi of new station, readonofsending);
			sendInfoSds($t_sds->tsi, $lipinfo->reasonforsending);

			# calculate distance RPT<->MS
			$sstcl = "distance_rpt_ms " . $t_sds->tsi . " " .
				calcDistance($own_lat, $own_lon, $lipinfo->latitude, $lipinfo->longitude) .
				" " .
				calcBearing($own_lat, $own_lon, $lipinfo->latitude, $lipinfo->longitude);
			print $sstcl . "\n";
#			processEvent(sstcl.str());

#			sdsinfo["lat"] = lipinfo.latitude;
#			sdsinfo["lon"] = lipinfo.longitude;
#			sdsinfo["reasonforsending"] = lipinfo.reasonforsending;
		}
		case STATE_SDS { # STATE_SDS
			print color('green'), "STATE_SDS\n" , color('reset');
			$isds = hex2int($sds);
			handleStateSds($isds);
#			userdata[$t_sds->tsi].state = $isds;
#			m_aprsinfo << ">" << "State:";
#			if ((it = state_sds.find(isds)) != state_sds.end()) {
#				m_aprsinfo << it->second;
#			}
#			m_aprsinfo << " (" << isds << ")";

			$ss = "state_sds_received " . $t_sds->tsi . " " . $isds;
#			sdsinfo["state"] = isds;
		}
	
		case TEXT_SDS { # TEXT_SDS
			print color('green'), "TEXT_SDS\n" , color('reset');
			$sds_txt = handleTextSds($sds);
			cfmTxtSdsReceived($sds, $t_sds->tsi);
#			$ss = "text_sds_received " . $t_sds->tsi . " \"" . $sds_txt . "\"";

			MessageRoute($sds_txt);
#			sdsinfo["content"] = sds_txt;
		}
		case SIMPLE_TEXT_SDS { # SIMPLE_TEXT_SDS
			print color('green'), "SIMPLE_TEXT_SDS\n" , color('reset');
			$sds_txt = handleSimpleTextSds($sds);
			MessageRoute($sds_txt);
			cfmSdsReceived($t_sds->tsi);
			$ss = "simple_text_sds_received " . $t_sds->tsi . " \"" . $sds_txt . "\"";
		}

		case ACK_SDS { # ACK_SDS
			print color('green'), "ACK_SDS\n" , color('reset');
			# +CTSDSR: 12,23404,0,23401,0,32
			# 82100002
			# sds msg received by MS from remote
			$t_sds->tod = time();
			$sds_txt = handleAckSds($sds, $t_sds->tsi);
#			$m_aprsinfo = ">ACK";
			$ss = "sds_received_ack " . $sds_txt;
		}

		case REGISTER_TSI { # REGISTER_TSI
			print color('green'), "REGISTER_TSI\n" , color('reset');
			$ss = "register_tsi " . $t_sds->tsi;
			cfmSdsReceived($t_sds->tsi);
		}

		case INVALID { # INVALID
			$ss = "unknown_sds_received";
			if ($debug >= LOGWARN) {
				print "*** Unknown type of SDS\n";
			}
		} else {
			return;
		}
	}

	my $ti = time();
#	sdsinfo["last_activity"] = ti;
#	sdsinfo["sendertsi"] = t_sds.tsi;
#	sdsinfo["type"] = m_sdstype;
#	sdsinfo["from"] = userdata[t_sds.tsi].call;
#	sdsinfo["to"] = userdata[pSDS.totsi].call;
#	sdsinfo["receivertsi"] = pSDS.totsi;
#	sdsinfo["gateway"] = callsign();
#	event.append(sdsinfo);
#	publishInfo("Sds:info", event);

	# send sds info of a user to aprs network
#	if (m_aprsinfo.str().length() > 0)
#	{
#		string m_aprsmessage = aprspath;
#		m_aprsmessage += m_aprsinfo.str();
#		sendAprs(userdata[t_sds.tsi].call, m_aprsmessage);
#	}

	if (length($ss) > 0)
	{
#		processEvent($ss);
	}
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


	if (rindex($m_message, "+CTGS: ", 0) == 0) {
		substr($m_message, 0, 7) = ""; # Replace in a string (used here to erase)
	}
	return $m_message;
}

####################################################
# 6.14.10 TETRA DMO visible gateways/repeaters
# * +CTDGR: [<DM communication type>], [<gateway/repeater address>], [<MNI>],
# *         [<presence information>]
# * TETRA DMO visible gateways/repeaters +CTDGR
# * +CTDGR: 2,1001,90116383,0
sub handleCtdgr {
	my ($m_message) = @_;

		substr($m_message, 0, 8) = ""; # Replace in a string (used here to erase)
	my $ss;
	my $ssret;
#	my $n = std::count(m_message.begin(), m_message.end(), ',');
	my $drp = DmoRpt->new();
#	my $mtime = tm->new(); #{0};

#	if ($n == 3) {
		my $dmct = getNextVal($m_message);
		$drp->issi(getNextVal($m_message));
		$drp->mni(getNextStr($m_message));
#		$drp->state(getNextVal($m_message));
#		$drp->last_activity(mktime($mtime));

#		$ssret = "INFO: Station " . TransientComType[dmct] . " detected (ISSI=" .
#			$drp->issi . ", MNI=" . $drp->mni . ", state=" . $drp.state . ")";

#		$dmo_rep_gw->emplace($drp->issi, $drp);

#		$ss = "dmo_gw_rpt " . $dmct . " " . $drp->issi . " " . $drp->mni . " " .
#			$drp->state;
#		processEvent($ss);
#	}

	return $ssret;
}

####################################################
sub handleClvl {
	my ($m_message) = @_;

	my $ss;
	if (rindex($m_message, "+CLVL: ", 0) == 0) {
		substr($m_message, 0, 7) = ""; # Replace in a string (used here to erase)
	}

	$ss = "audio_level " . getNextVal($m_message);
#	processEvent($ss);
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

	if ($last_sdsinstance eq $sds_inst) {
		if ($state == SDS_SEND_FAILED) {
			if ($debug>= LOGERROR) {
				print color('red'), "*** ERROR: Send message failed. Will send again...\n", color('reset');
			}
			$pending_sds->tos(0);
		} elsif ($state == SDS_SEND_OK) {
			if ($debug >= LOGINFO) {
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

	print color('green'), "handleTextSds\n", color('reset');

	if (length($m_message) > 8) {
		# delete 00A3xxxx
		substr($m_message, 0, 8) = ""; # Replace in a string (used here to erase)
	}
	return decodeSDS($m_message);
}

####################################################
sub handleAckSds {
	my ($m_message, $tsi) = @_;
	
	my $t_msg;
	$t_msg = $t_msg . $tsi;
	return $t_msg;
}

####################################################
sub handleSimpleTextSds {
	my ($m_message) = @_;

	if (length($m_message) > 4) {
		# delete 0201
		substr($m_message, 0, 4) = ""; # Replace in a string (used here to erase)
	}
	return decodeSDS($m_message);

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

	my $ss;
#	char is[18];
	my $is;
	my $len = length($issi); 
	my $t_mcc;
	my $t_issi;

	if ($len < 9) {
		$is = sprintf("%08d", int($issi));
		$ss = $mcc . $mnc . $is;
		return $ss;
	}

	# get MCC (3 or 4 digits)
	if (substr($issi, 0, 1) == "0") {
		$t_mcc = int(substr($issi, 0, 4));
		substr($issi, 0, 4) = ""; # Replace in a string (used here to erase)
	} else {
		$t_mcc = int(substr($issi, 0, 3));
		substr($issi, 0, 3) = ""; # Replace in a string (used here to erase)
	}

	# get ISSI (8 digits)
	$t_issi = substr($issi, $len - 8, 8);
	substr($issi, 0, 8) = ""; # Replace in a string (used here to erase)

	$is =  sprintf("%04d%05d%s", $t_mcc, int($issi), $t_issi);
	$ss = $is;

	return $ss;
}

####################################################
sub handleStateSds {
	my ($isds) = @_;

	my $ss;
	if ($debug >= LOGINFO) {
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

	if ($tetra_modem_sql == 1) {
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
	my @clear = ();
	$Qso->members(@clear);
	print "scalar QSO =" . scalar($Qso->members) . "\n";

	$inTransmission = 0;
	checkSds(); # resend Sds after MS got into Rx mode

}



####################################################
sub joinList {
	my ($members) = @_;

}

##################################################################
sub sendPei {
	my ($Buffer) = @_;

	if ($debug) {print color('green'), "sendPei.\n", color('reset');}

	if (substr($Buffer, -1) ne chr(0x1A)) {
		$Buffer = $Buffer . chr(0x0D);
	}
	$SerialPort->write($Buffer);
	if ($debug >= 2) {print "\t" . $Buffer . "\n";}
	if ($debug >= 3) {Bytes_2_HexString($Buffer);}

	if ($debug) {print "\tsendPei Done.\n";}

	$peiComTimer->timeout(time() + $peiComTimer->interval);
	$peiComTimer->enabled(1);
}

####################################################
sub onComTimeout {
	my $ss = "peiCom_timeout\n";
	print $ss;
#	processEvent(ss);
	$peistate = TIMEOUT;
}

####################################################
sub onPeiActivityTimeout {
	sendPei("AT");
	$peirequest = CHECK_AT;
	$peiActivityTimer->timeout(time() + $peiActivityTimer->interval); # Reset()
}

####################################################
sub onPeiBreakCommandTimeout {
	$peirequest = INIT_;
	initPei();
}

####################################################
#Create a confirmation sds and sends them to the Tetra radio
sub cfmSdsReceived {
	my ($tsi) = @_;

	my $msg = "OK";
	my $t_sds = Sds->new();
	$t_sds->nroftries(0);
	$t_sds->message = $msg;
	$t_sds->tsi = $tsi;
	$t_sds->direction = OUTGOING;
	queueSds($t_sds);
}


####################################################
# +CTSDSR: 12,23404,0,23401,0,96, 82041D014164676A6D707477 */
sub cfmTxtSdsReceived {
	my ($message, $tsi) = @_;

	if (length($message) < 8) {
		return;
	}
	my $id = substr($message, 4, 2);
print "id = " . $id . "\n";
	my $msg = "821000"; # confirm a sds received
	$msg = $msg . $id;
print "msg = " . $msg . "\n";

	if ($debug >= LOGINFO) {
		print "+++ sending confirmation Sds to " . $tsi . "\n";
	}

	my $t_sds = Sds->new();
	$t_sds->nroftries(0);
	$t_sds->message($msg);
	$t_sds->id(hex2int($id));
	$t_sds->remark("confirmation Sds");
	$t_sds->tsi($tsi);
	$t_sds->type(ACK_SDS);
	$t_sds->direction(OUTGOING);
	
	print "msg " . $t_sds->message . "\n";
	print "tsi " .$t_sds->tsi . "\n";
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
	
	if ($debug >= LOGINFO) {
		print "<num type> is " . $m_numtype . " (" .
			NumType($m_numtype) . ")\n";
	}
	if ($m_numtype == 6 || $m_numtype == 0) {
		# get the tsi and split it into mcc,mnc,issi
		splitTsi($m_message, $t_mcc, $t_mnc, $t_issi);
		# check if the configured MCC fits to MCC in MS
		if ($t_mcc != $mcc) {
			if ($debug >= LOGWARN) {
				print color('red'), "*** ERROR: wrong MCC in MS, will not work! " .
					$mcc . "!=" . $t_mcc . "\n", color('reset');
			}
		}

		 # check if the configured MNC fits to MNC in MS
		if ($t_mnc != $mnc) {
			if ($debug >= LOGWARN) {
				print color('red'), "*** ERROR: wrong MNC in MS, will not work! " .
					$mnc . "!=" . $t_mnc . "\n", color('reset');
			}
		}
		$dmcc = $t_mcc;
		$dmnc = $t_mnc;

		if ($issi != $t_issi) {
			if ($debug >= LOGWARN) {
				print color('red'), "*** ERROR: wrong ISSI in MS, will not work! " .
					$issi . "!=" . $t_issi . "\n", color('reset');
			}
		}
	}

	$peirequest = INIT_COMPLETE;
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
			if ($debug >= 3) {
				print "$hour:$min:$sec peiComTimer timer.\n";
				print "	Timer Timeout @{[int time - $^T]}\n";
			}
			onComTimeout();
			if ($debug) {
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
			if ($debug >= 4) {
				print "peiActivityTimer Enabled ". $peiActivityTimer->enabled . 
					" timeout " . $peiActivityTimer->timeout . " Time " . time() .
					" interval " . $peiActivityTimer->interval . "\n";
			}
		if (time() >= $peiActivityTimer->timeout) {
			print color('green'), "peiActivityTimer event\n", color('reset');
			#print "peiActivityTimer Enabled ". $peiActivityTimer->enabled . " timeout " . $peiActivityTimer->timeout . " Time " . time() . "\n";
			if ($debug >= 4) {
				print "$hour:$min:$sec peiActivityTimer timer.\n";
				print "	Timer Timeout @{[int time - $^T]}\n";
			}
			onPeiActivityTimeout();
			if ($debug) {
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
			if ($debug >= 3) {
				print "$hour:$min:$sec peiBreakCommandTimer timer.\n";
				print "	Timer Timeout @{[int time - $^T]}\n";
			}
			onPeiBreakCommandTimeout();
			if ($debug) {
				print "----------------------------------------------------------------------\n";
			}
			$peiBreakCommandTimer->timeout(time() + $peiBreakCommandTimer->interval);
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



####################################################
sub handleMessage {
	my ($mseg) = @_;

	my $retvalue = INVALID;

	if (substr($mseg,0,2) eq "OK") {
		return OK;
	} elsif (rindex($mseg, "+CME ERROR:", 0) == 0) {
		return ERROR;
	} elsif (rindex($mseg, "+CTSDSR:", 0) == 0) { # SDS
		return SDS;
	} elsif (rindex($mseg, "+CTICN:", 0) == 0) { # CALL_BEGIN
		return CALL_BEGIN;
	} elsif (rindex($mseg, "+CTCR:", 0) == 0) { # CALL_RELEASED
		return CALL_RELEASED;
	} elsif (rindex($mseg, "+CTCC:", 0) == 0) { # CALL_CONNECT
		return CALL_CONNECT;
	} elsif (rindex($mseg, "+CDTXC:", 0) == 0) { # TRANSMISSION_END
		return TRANSMISSION_END;
	} elsif (rindex($mseg, "+CTXG:", 0) == 0) { # TRANSMISSION_GRANT
		return TRANSMISSION_GRANT;
# TX_DEMAND
		return TX_DEMAND;
# TX_INTERRUPT
		return TX_INTERRUPT;
# TX_WAIT
		return TX_WAIT;
# MS_CNUM
		return MS_CNUM;
	} elsif ((rindex($mseg, "+CTOM:", 0) == 0) and # OP_MODE
			(ord(substr($mseg, 7, 8)) >= 0x30) and (ord(substr($mseg, 7, 8)) <= 0x39)) {
		return OP_MODE;
	} elsif (rindex($mseg, "+CMGS:", 0) == 0) { # CMGS
		return CMGS;
	} elsif (rindex($mseg, "+CNUMF:", 0) == 0) { # CNUMF, Local Radio MCC, MNC and ISSI
		return CNUMF;
	} elsif (rindex($mseg, "+CTGS:", 0 ) == 0) { # CTGS
		return CTGS;
	} elsif (rindex($mseg, "+CTDGR:", 0) == 0) { # CTDGR
		return CTDGR;
	} elsif (rindex($mseg, "+CLVL:", 0) == 0) { # CLVL
		return CLVL;
	} elsif (rindex($mseg, "01", 0) == 0) { # OTAK
		return OTAK;
	} elsif (rindex($mseg, "02", 0) == 0) { # SIMPLE_TEXT_SDS
		return SIMPLE_TEXT_SDS;
	} elsif (rindex($mseg, "03", 0) == 0) { # SIMPLE_LIP_SDS
		return SIMPLE_LIP_SDS;
	} elsif (rindex($mseg, "04", 0) == 0) { # WAP_PROTOCOL
		return WAP_PROTOCOL;
	} elsif ((rindex($mseg, "0A", 0) == 0) and # LIP_SDS
			((ord(substr($mseg, 2, 3)) >= 0x30) and (ord(substr($mseg, 2, 3)) <= 0x39) or
			(ord(substr($mseg, 2, 3)) >= 0x41) and (ord(substr($mseg, 2, 3)) <= 0x46)) and
			((ord(substr($mseg, 3, 4)) >= 0x30) and (ord(substr($mseg, 3, 4)) <= 0x39) or
			(ord(substr($mseg, 3, 4)) >= 0x41) and (ord(substr($mseg, 3, 4)) <= 0x46)) and
			((ord(substr($mseg, 4, 5)) >= 0x30) and (ord(substr($mseg, 4, 5)) <= 0x39) or
			(ord(substr($mseg, 4, 5)) >= 0x41) and (ord(substr($mseg, 4, 5)) <= 0x46)) and
			((ord(substr($mseg, 5, 6)) >= 0x30) and (ord(substr($mseg, 5, 6)) <= 0x39) or
			(ord(substr($mseg, 5, 6)) >= 0x41) and (ord(substr($mseg, 5, 6)) <= 0x46)) and
			((ord(substr($mseg, 6, 7)) >= 0x30) and (ord(substr($mseg, 6, 7)) <= 0x39) or
			(ord(substr($mseg, 6, 7)) >= 0x41) and (ord(substr($mseg, 6, 7)) <= 0x46)) and
			((ord(substr($mseg, 7, 8)) >= 0x30) and (ord(substr($mseg, 7, 8)) <= 0x39) or
			(ord(substr($mseg, 7, 8)) >= 0x41) and (ord(substr($mseg, 7, 8)) <= 0x46)) and
			((ord(substr($mseg, 8, 9)) >= 0x30) and (ord(substr($mseg, 8, 9)) <= 0x39) or
			(ord(substr($mseg, 8, 9)) >= 0x41) and (ord(substr($mseg, 8, 9)) <= 0x46)) and
			((ord(substr($mseg, 9, 10)) >= 0x30) and (ord(substr($mseg, 9, 10)) <= 0x39) or
			(ord(substr($mseg, 9, 10)) >= 0x41) and (ord(substr($mseg, 9, 10)) <= 0x46)) and
			((ord(substr($mseg, 10, 11)) >= 0x30) and (ord(substr($mseg, 10, 11)) <= 0x39) or
			(ord(substr($mseg, 10, 11)) >= 0x41) and (ord(substr($mseg, 10, 11)) <= 0x46)) and
			((ord(substr($mseg, 11, 12)) >= 0x30) and (ord(substr($mseg, 11, 12)) <= 0x39) or
			(ord(substr($mseg, 11, 12)) >= 0x41) and (ord(substr($mseg, 11, 12)) <= 0x46)) and
			((ord(substr($mseg, 12, 13)) >= 0x30) and (ord(substr($mseg, 12, 13)) <= 0x39) or
			(ord(substr($mseg, 12, 13)) >= 0x41) and (ord(substr($mseg, 12, 13)) <= 0x46)) and
			((ord(substr($mseg, 13, 14)) >= 0x30) and (ord(substr($mseg, 13, 14)) <= 0x39) or
			(ord(substr($mseg, 13, 14)) >= 0x41) and (ord(substr($mseg, 13, 14)) <= 0x46))) {
		return LIP_SDS;
	} elsif ((length($mseg) == 4) and # STATE_SDS
			((ord(substr($mseg, 0, 1)) >= 0x38) and (ord(substr($mseg, 0, 1)) <= 0x39)) and
			((ord(substr($mseg, 1, 2)) >= 0x30) and (ord(substr($mseg, 1, 2)) <= 0x39) or
			(ord(substr($mseg, 1, 2)) >= 0x41) and (ord(substr($mseg, 1, 2)) <= 0x46)) and
			((ord(substr($mseg, 2, 3)) >= 0x30) and (ord(substr($mseg, 2, 3)) <= 0x39) or
			(ord(substr($mseg, 2, 3)) >= 0x41) and (ord(substr($mseg, 2, 3)) <= 0x46)) and
			((ord(substr($mseg, 3, 4)) >= 0x30) and (ord(substr($mseg, 3, 4)) <= 0x39) or
			(ord(substr($mseg, 3, 4)) >= 0x41) and (ord(substr($mseg, 3, 4)) <= 0x46))) {
		return STATE_SDS;
	} elsif (rindex($mseg, "8210", 0) == 0) { # ACK_SDS
		return ACK_SDS;
	} elsif (rindex($mseg, "8", 0) == 0) { # TEXT_SDS
		return TEXT_SDS;
#	} elsif (rindex($mseg, "83", 0) == 0) { # WAP_MESSAGE
#		return $WAP_MESSAGE;
#	} elsif (rindex($mseg, "84", 0) == 0) { # CONCAT_SDS
#		return CONCAT_SDS;
	#} elsif ($mseg[0 : 1] == '') { # COMPLEX_SDS
		#return $COMPLEX_SDS;
	} elsif (rindex($mseg, "0C", 0) == 0) { # CONCAT_SDS
		return CONCAT_SDS;
	} elsif (rindex($mseg, "+CTXD:", 0) == 0) { # TX_DEMAND
		return TX_DEMAND;
	} elsif (rindex($mseg, "INVALID", 0) == 0) {
		return INVALID;
	} else {
		return $peistate;
	}
}

sub MessageRoute {
	my ($sds_txt) = @_;

	print color('green'), "MessageRoute\n", color('reset');
	# DAPNET
	my $header = lc(substr($sds_txt, 0, 4));
	if ($header eq "dap ") {
		print "Dapnet\n";
		if (checkIfDapmessage($sds_txt)) {
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
		if ($debug >= LOGDEBUG) {
			print "To APRS: call = " . $destcall . ", sds message: " . $msg . "\n";
		}
		APRS_Message($destcall, $msg);
	}

	# PTTLink
	$header = lc(substr($sds_txt, 0, 4));
	if ($header eq "ptt ") {
		print "PTTLink\n";
		substr($sds_txt, 0, 4) = ""; # Replace in a string (used here to erase)
		if ($debug >= LOGDEBUG) {
			print "To PTTLink: sds message: $sds_txt \n";
		}
		PTTLink::RptFun($Node_Number, $sds_txt);
	}
}

####################################################
sub queueSds {
	my ($t_sds) = @_;

	my $s = scalar @sdsQueue + 1;
	$t_sds->tos(0);
	push(@sdsQueue, $t_sds);
	$new_sds = checkSds();
	return scalar @sdsQueue;
}

####################################################
sub checkSds {

	print color('green'), "checkSds\n", color('reset');

	my $retsds = 0;
	my @todelete;
	if (not $cmgs_received) {
		return 1;
	}

print Dumper \@sdsQueue;

	# get first Sds back
	foreach my $sdsQueue(@sdsQueue) {

		print "sdsQueue " . $sdsQueue . "\n";
		print "tsi " . $sdsQueue->tsi . "\n";
		print "id " . $sdsQueue->id . "\n";
		print "direction " . $sdsQueue->direction . "\n";
		print "message " . $sdsQueue->message . "\n";
		print "remark " . $sdsQueue->remark . "\n";
		print "type " . $sdsQueue->type . "\n";
		print "tos " . $sdsQueue->tos . "\n";
		print "nroftries " . $sdsQueue->nroftries . "\n\n";
#		print "tod " . $sdsQueue[$x]->tod . "\n";
#		print "aiservice " . $sdsQueue[$x]->aiservice . "\n";

		# delete all old Sds
		if (($sdsQueue->tos != 0) and (($sdsQueue->tos + time()) > 3600)) {
			print "todelete\n";
			push(@todelete, $sdsQueue);
		}

		if (($sdsQueue->tos == 0) and ($sdsQueue->direction == TetraLogic::OUTGOING)) {
			$sdsQueue->nroftries($sdsQueue->nroftries + 1);
			# send Sds only if PEI=ok & MS is NOT sending & MS is NOT receiving
			if (($peistate == TetraLogic::OK) and !$inTransmission and (!$tetra_modem_sql == 1)) {
				print "peistate = OK and not $inTransmission and tetra_modem_sql = 1\n";
				my $t_sds;
				if ($sdsQueue->type == TetraLogic::ACK_SDS) {
					createCfmSDS($t_sds, getISSI($sdsQueue->tsi), $sdsQueue->message);
				} else {
					createSDS($t_sds, getISSI($sdsQueue->tsi), $sdsQueue->message);
				}

				$sdsQueue->tos(time());
				if ($debug >= TetraLogic::LOGINFO) {
					print "+++ sending Sds (type=" . $sdsQueue->type . ") " .
						getISSI($sdsQueue->tsi) . " \"" . $sdsQueue->message .
						"\", tries: " . $sdsQueue->nroftries . "\n";
				}
				$cmgs_received = 0;
				$retsds = 1;
#				$pending_sds = $it->second;
				sendPei($t_sds);
			} else {
				# in the case that the MS is on TX the Sds could not be send
				if ($debug >= TetraLogic::LOGWARN) {
					 print "+++ MS not ready, trying to send Sds to " . $sdsQueue->tsi .
						" later...\n";
				}
			}
		}
		$retsds = 1;
	}

	foreach my $todelete(@todelete) {
#		splice (@sdsQueue, $todelete, 1);
	}

	return $retsds;
}


####################################################
sub sendWelcomeSds {
	my ($tsi, $r4s) = @_;

#	my $oa = sds_on_activity.find($r4s);

	# send welcome sds to new station, if defined
#	if ($oa != sds_on_activity.end()) {
		my $t_sds = Sds->new();
		$t_sds->direction(OUTGOING);
		$t_sds->tsi($tsi);
		$t_sds->remark("welcome sds");
#		$t_sds->message = $oa->second;

		if ($debug >= LOGINFO) {
			print "Send SDS:" . getISSI($t_sds->tsi) . ", " .
				$t_sds->message . "\n";
		}
		queueSds($t_sds);
#	}
}




















# Constants





#



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
	my ($mseg) = @_;

	my $retvalue = INVALID;

	if (substr($mseg,0,2) eq "OK") {
		return OK;
	} elsif (rindex($mseg, "+CME ERROR:", 0) == 0) {
		return ERROR;
	} elsif (rindex($mseg, "+CTSDSR:", 0) == 0) { # SDS
		return SDS;
	} elsif (rindex($mseg, "+CTICN:", 0) == 0) { # CALL_BEGIN
		return CALL_BEGIN;
	} elsif (rindex($mseg, "+CTCR:", 0) == 0) { # CALL_RELEASED
		return CALL_RELEASED;
	} elsif (rindex($mseg, "+CTCC:", 0) == 0) { # CALL_CONNECT
		return CALL_CONNECT;
	} elsif (rindex($mseg, "+CDTXC:", 0) == 0) { # TRANSMISSION_END
		return TRANSMISSION_END;
	} elsif (rindex($mseg, "+CTXG:", 0) == 0) { # TRANSMISSION_GRANT
		return TRANSMISSION_GRANT;
# TX_DEMAND
		return TX_DEMAND;
# TX_INTERRUPT
		return TX_INTERRUPT;
# TX_WAIT
		return TX_WAIT;
# MS_CNUM
		return MS_CNUM;
	} elsif ((rindex($mseg, "+CTOM:", 0) == 0) and # OP_MODE
			(ord(substr($mseg, 7, 8)) >= 0x30) and (ord(substr($mseg, 7, 8)) <= 0x39)) {
		return OP_MODE;
	} elsif (rindex($mseg, "+CMGS:", 0) == 0) { # CMGS
		return CMGS;
	} elsif (rindex($mseg, "+CNUMF:", 0) == 0) { # CNUMF, Local Radio MCC, MNC and ISSI
		return CNUMF;
	} elsif (rindex($mseg, "+CTGS:", 0 ) == 0) { # CTGS
		return CTGS;
	} elsif (rindex($mseg, "+CTDGR:", 0) == 0) { # CTDGR
		return CTDGR;
	} elsif (rindex($mseg, "+CLVL:", 0) == 0) { # CLVL
		return CLVL;
	} elsif (rindex($mseg, "01", 0) == 0) { # OTAK
		return OTAK;
	} elsif (rindex($mseg, "02", 0) == 0) { # SIMPLE_TEXT_SDS
		return SIMPLE_TEXT_SDS;
	} elsif (rindex($mseg, "03", 0) == 0) { # SIMPLE_LIP_SDS
		return SIMPLE_LIP_SDS;
	} elsif (rindex($mseg, "04", 0) == 0) { # WAP_PROTOCOL
		return WAP_PROTOCOL;
	} elsif ((rindex($mseg, "0A", 0) == 0) and # LIP_SDS
			((ord(substr($mseg, 2, 3)) >= 0x30) and (ord(substr($mseg, 2, 3)) <= 0x39) or
			(ord(substr($mseg, 2, 3)) >= 0x41) and (ord(substr($mseg, 2, 3)) <= 0x46)) and
			((ord(substr($mseg, 3, 4)) >= 0x30) and (ord(substr($mseg, 3, 4)) <= 0x39) or
			(ord(substr($mseg, 3, 4)) >= 0x41) and (ord(substr($mseg, 3, 4)) <= 0x46)) and
			((ord(substr($mseg, 4, 5)) >= 0x30) and (ord(substr($mseg, 4, 5)) <= 0x39) or
			(ord(substr($mseg, 4, 5)) >= 0x41) and (ord(substr($mseg, 4, 5)) <= 0x46)) and
			((ord(substr($mseg, 5, 6)) >= 0x30) and (ord(substr($mseg, 5, 6)) <= 0x39) or
			(ord(substr($mseg, 5, 6)) >= 0x41) and (ord(substr($mseg, 5, 6)) <= 0x46)) and
			((ord(substr($mseg, 6, 7)) >= 0x30) and (ord(substr($mseg, 6, 7)) <= 0x39) or
			(ord(substr($mseg, 6, 7)) >= 0x41) and (ord(substr($mseg, 6, 7)) <= 0x46)) and
			((ord(substr($mseg, 7, 8)) >= 0x30) and (ord(substr($mseg, 7, 8)) <= 0x39) or
			(ord(substr($mseg, 7, 8)) >= 0x41) and (ord(substr($mseg, 7, 8)) <= 0x46)) and
			((ord(substr($mseg, 8, 9)) >= 0x30) and (ord(substr($mseg, 8, 9)) <= 0x39) or
			(ord(substr($mseg, 8, 9)) >= 0x41) and (ord(substr($mseg, 8, 9)) <= 0x46)) and
			((ord(substr($mseg, 9, 10)) >= 0x30) and (ord(substr($mseg, 9, 10)) <= 0x39) or
			(ord(substr($mseg, 9, 10)) >= 0x41) and (ord(substr($mseg, 9, 10)) <= 0x46)) and
			((ord(substr($mseg, 10, 11)) >= 0x30) and (ord(substr($mseg, 10, 11)) <= 0x39) or
			(ord(substr($mseg, 10, 11)) >= 0x41) and (ord(substr($mseg, 10, 11)) <= 0x46)) and
			((ord(substr($mseg, 11, 12)) >= 0x30) and (ord(substr($mseg, 11, 12)) <= 0x39) or
			(ord(substr($mseg, 11, 12)) >= 0x41) and (ord(substr($mseg, 11, 12)) <= 0x46)) and
			((ord(substr($mseg, 12, 13)) >= 0x30) and (ord(substr($mseg, 12, 13)) <= 0x39) or
			(ord(substr($mseg, 12, 13)) >= 0x41) and (ord(substr($mseg, 12, 13)) <= 0x46)) and
			((ord(substr($mseg, 13, 14)) >= 0x30) and (ord(substr($mseg, 13, 14)) <= 0x39) or
			(ord(substr($mseg, 13, 14)) >= 0x41) and (ord(substr($mseg, 13, 14)) <= 0x46))) {
		return LIP_SDS;
	} elsif ((length($mseg) == 4) and # STATE_SDS
			((ord(substr($mseg, 0, 1)) >= 0x38) and (ord(substr($mseg, 0, 1)) <= 0x39)) and
			((ord(substr($mseg, 1, 2)) >= 0x30) and (ord(substr($mseg, 1, 2)) <= 0x39) or
			(ord(substr($mseg, 1, 2)) >= 0x41) and (ord(substr($mseg, 1, 2)) <= 0x46)) and
			((ord(substr($mseg, 2, 3)) >= 0x30) and (ord(substr($mseg, 2, 3)) <= 0x39) or
			(ord(substr($mseg, 2, 3)) >= 0x41) and (ord(substr($mseg, 2, 3)) <= 0x46)) and
			((ord(substr($mseg, 3, 4)) >= 0x30) and (ord(substr($mseg, 3, 4)) <= 0x39) or
			(ord(substr($mseg, 3, 4)) >= 0x41) and (ord(substr($mseg, 3, 4)) <= 0x46))) {
		return STATE_SDS;
	} elsif (rindex($mseg, "8210", 0) == 0) { # ACK_SDS
		return ACK_SDS;
	} elsif (rindex($mseg, "8", 0) == 0) { # TEXT_SDS
		return TEXT_SDS;
#	} elsif (rindex($mseg, "83", 0) == 0) { # WAP_MESSAGE
#		return $WAP_MESSAGE;
#	} elsif (rindex($mseg, "84", 0) == 0) { # CONCAT_SDS
#		return CONCAT_SDS;
	#} elsif ($mseg[0 : 1] == '') { # COMPLEX_SDS
		#return $COMPLEX_SDS;
	} elsif (rindex($mseg, "0C", 0) == 0) { # CONCAT_SDS
		return CONCAT_SDS;
	} elsif (rindex($mseg, "+CTXD:", 0) == 0) { # TX_DEMAND
		return TX_DEMAND;
	} elsif (rindex($mseg, "INVALID", 0) == 0) {
		return INVALID;
	} else {
		return $peistate;
	}
}

####################################################
sub getAiMode {
	my ($aimode) = @_;

	if (length($aimode) > 6) {
		my $t = substr($aimode, 0, 6) = ""; # Replace in a string (used here to erase)
		if ($debug >= LOGINFO) {
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
sub onPublishStateEvent {
	my ($event_name, $msg) = @_;

}

####################################################
sub publishInfo {
	my ($type, $event) = @_;

}




####################################################
# @param: a message, e.g. +CTCC: 1,1,1,0,0,1,1
# * @return: the current caller identifier
sub handleCci {
	my ($m_message) = @_;

}

####################################################
sub onDapnetMessage {
	my ($tsi, $message) = @_;

	if ($debug >= LOGINFO) {
		print "+++ new Dapnet message received for " . $tsi .
			":" . $message . "\n";
	}
	# put the new Sds int a queue...
	my $t_sds = Sds->new();
	$t_sds->tsi($tsi);
	$t_sds->remark("DAPNET message");
	$t_sds->message($message);
	$t_sds->direction(OUTGOING);
	$t_sds->type(TEXT);

	queueSds($t_sds);
}

####################################################
sub checkIfDapmessage {
	my ($message) = @_;

#	if ($dapnetclient) {
		my $header = lc(substr($message, 0, 4));
		if ($header eq "dap ") {
			my ($cmd, $destcall, @words) = @$message;
			my $msg = join(' ', @words);
			if ($debug >= LOGDEBUG) {
				print "To DAPNET: call=" . $destcall . ", message:" . $msg . "\n";
			}
#			$dapnetclient->sendDapMessage($destcall, $msg);
			return 1;
		}
#	}
	return 0;
}



1;