#package TetraLib;

# Strict and warnings recommended.
use strict;
use warnings;
use Switch;
use Term::ANSIColor;
use Class::Struct;
use Math::Trig;
use POSIX qw(fmod);
use POSIX qw(modf);



# Misc from other pm
struct( Coordinate => [
	deg => '$',
	min => '$',
	sec => '$',
]);

my $pos = Coordinate->new();








use constant RADIUS => 6378.16; # Earth radius

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

struct( LipInfo => [
	time_elapsed => '$',
	latitude => '$',
	longitude => '$',
	positionerror => '$',
	horizontalvelocity => '$',
	directionoftravel => '$',
	reasonforsending => '$',
]);

sub dec2nmea_lat {
	my ($latitude) = @_;
print "latitude $latitude \n";
	my $lat;
	my $normalizedLat = POSIX::fmod($latitude, 180.0);
print "normalizedLat $normalizedLat \n";
	my ($fractpart, $degrees) = POSIX::modf(abs($normalizedLat));
print "degrees $degrees \n";
print "fractpart $fractpart \n";
	my $minute = $fractpart * 60.0;
print "minute $minute \n";
	my $dir;
	if ($normalizedLat > 0.0) {
		$dir = "N";
	} else {
		$dir = "S";
	}
	$minute = sprintf("%.2f", $minute);
	for (my $x = 0; $x < 1; $x++) {
		if (length(int($minute)) < 2) {
			$minute = "0" . $minute;
		}
	}
	$lat = sprintf("%02d", $degrees) . $minute . $dir;
	print "lat test $lat \n\n";
	return $lat;
}

sub dec2nmea_lon {
	my ($longitude) = @_;
	
	my $lon;
	my $normalizedLon = POSIX::fmod($longitude, 360.0);
	my ($fractpart, $degrees) = POSIX::modf(abs($normalizedLon));
	my $minute = $fractpart * 60.0;
	my $dir;
	if ($normalizedLon > 0.0) {
		$dir = "E";
	} else {
		$dir = "W";
	}
	$minute = sprintf("%.2f", $minute);
	for (my $x = 0; $x < 1; $x++) {
		if (length(int($minute)) < 2) {
			$minute = "0" . $minute;
		}
	}
	$lon = sprintf("%03d", $degrees) . $minute . $dir;
	print "Lon = " . $lon;
	return $lon;
}

sub handle_LIP_compact {
	my ($lip, $lat,$lon) = @_;
	
	if (length($lip) < 18) {
		return 0;
	}
	my $ss;
	my $mlatl;
	my $mlonl;

	# calculate latitude
	my $m_lat = substr($lip, 7, 6);
	$ss = hex($m_lat);
#	$ss >> $mlatl;
	$mlatl *= 180;
	$lat = $mlatl / 16777216;
#	$ss.clear();

	# calculate longitude
	# 0A06B8ACA67F1822FFE810
	my $m_lon = substr($lip, 13, 6);
#	$ss << hex($m_lon);
#	$ss >> $mlonl;
#	$mlonl *= 360;
	$lon = $mlonl / 16777216;

	# lt1 = sprintf("%06.3fN",($lat - int($lat))*60);
	# $lat = int($lat).$lt1;
	return 1;
}

sub handleLipSds {
	my ($in, $lipinfo) = @_;

	# Protocol identifier
	# 0x02 = Simple Text Messaging
	# 0x03 = Simple location system
	# 0x06 = M-DMO (Managed DMO)
	# 0x09 = Simple immediate text messaging
	# 0x0A = LIP (Location Information Protocol)
	# 0x0C = Concatenated SDS message
	# 0x82 = Text Messaging
	# 0x83 = Complex SDS-TL GPS message transfer

	my $tla;
	my $tlo;

	my $t_velo;
	my $t_dot;

	# 0A0088BD4247F737FFE810 - short position report PDU
	# 0A4E73DDA841F55809493CC081 - long position report PDU
	# There is a small problem with the PEI answer, the length of
	# SDS is specified as 84 bits:
	# +CTSDSR: 12,2269001,0,9999,0,84
	# 0A112853A9FF4D4FFFE810 <- 22 digits
	# but 22 chars are 88 bits long, so the output in the first part
	# of the PEI response is incorrect (84 != 88). Could it well be
	# a cps problem in the Motorola MS?
	# 0A112853A9FF4D4FFFE810 - from YO9ION (Motorola MTP6650+MTM800E)
	# In N5UWU's PEI response, the last character (0) is missing and the
	# length of 21 chars corresponds to the specified bit length of 84 bits.
	# 0A0BA7D5B95BC50AFFE16 - from N5UWU (Sepura SEG3900 and STP9240)

	if (substr($in, 0, 2) eq "0A") {# LIP
		# check that is a shor position report
		if (int(substr($in, 2, 1) & 0x0c) != 0) {
			print "*** ERROR: Only PDU type=0 supported at the moment," .
				" check that you have configured \"short location report PDU\"" .
				" in your codeplug.\n";
			return;
		}

		$lipinfo->time_elapsed(int(substr($in, 2, 1)) & 0x03);


		$tlo = int(ord(substr($in, 3, 1))) << 21;
		$tlo += int(ord(substr($in, 4, 1))) << 17;
		$tlo += int(ord(substr($in, 5, 1))) << 13;
		$tlo += int(ord(substr($in, 6, 1))) << 9;
		$tlo += int(ord(substr($in, 7, 1))) << 5;
		$tlo += int(ord(substr($in, 8, 1))) << 1;
		$tlo += (int(ord(substr($in, 9, 1)) & 0x08)) >> 3;

		$tla = (int(ord(substr($in, 9, 1)) & 0x07)) << 21;
		$tla += int(ord(substr($in, 10, 1))) << 17;
		$tla += int(ord(substr($in, 11, 1))) << 13;
		$tla += int(ord(substr($in, 12, 1))) << 9;
		$tla += int(ord(substr($in, 13, 1))) << 5;
		$tla += int(ord(substr($in, 14, 1))) << 1;
		$tla += (int(ord(substr($in, 15, 1)) & 0x08)) >> 3;

		if ($tlo > 16777216) {
			$lipinfo->longitude($tlo * 360.0 / 33554432 - 360.0);
		} else {
			$lipinfo->longitude($tlo * 360.0 / 33554432);
		}

		if ($tla > 8388608) {
			$lipinfo->latitude($tla * 360.0 / 33554432 - 360.0);
		} else {
			$lipinfo->latitude($tla * 360.0 / 33554432);
		}

		# position error in meter
#		$lipinfo->positionerror(2 * (10 ** (int(substr($in, 15, 1),nullptr,16) & 0x03)));

		# Horizontal velocity shall be encoded for speeds 0 km/h to 28 km/h in 1 km/h
		# steps and from 28 km/h onwards using equation:
		# v = C × (1 + x)^(K-A) + B where:
		# • C = 16
		# • x = 0,038
		# • A = 13
		# • K = Horizontal velocity information element value
		# • B = 0

		$t_velo = int(ord(substr($in, 16, 1))) << 3;
		$t_velo += (int(ord(substr($in, 17, 1))) & 0x0e) >> 1;
		if ($t_velo < 29) {
			$lipinfo->horizontalvelocity($t_velo);
		} else {
			$lipinfo->horizontalvelocity(16 * (1.038 ** ($t_velo - 13)));
		}

		# definition can be expressed also by equation:
		# Direction of travel value = trunc((direction + 11,25)/22,5), when
		# direction is given in degrees.

		$t_dot = (int(ord(substr($in, 17, 1))) & 0x01) << 3;
		$t_dot += (int(ord(substr($in, 18, 1))) & 0x0e) >> 1;
		$lipinfo->directionoftravel($t_dot * 22.5);

		# reason for sending
		$lipinfo->reasonforsending(int(substr($in, 19, 1)));

	}
	# (NMEA) 0183 over SDS-TL
	# $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
	elsif (substr($in, 0, 2) == "03") {
		# to do
	}

}

sub createSDS {
	my ($sds, $issi, $message) = @_;

	if ((length($message) > 120) or (length($issi) > 8) or (length($issi) == 0)) {
		return 0;
	}
	
	my $ss;
#	$ss = "8204" . std::setfill('0') . std::setw(sizeof(short))
#		 << std::hex << getSdsMesgId() . "01";

	for (my $a = 0; $a < length($message); $a++) {
#		$ss = hex(int($message[$a]));
	}

#	my $f[length($ss) + length($issi) + 20];
#	sprintf(f, "AT+CMGS=%s,%03d\r\n%s%c",
#						 std::to_string(std::stoi(issi)).c_str(),
#						 (int)ss.str().length() * 4,
#						 ss.str().c_str(), 0x1a);
#	$sds = $f;
	return 1;
}

sub createRawSDS {
	my ($sds, $issi, $message) = @_;
	if ((length($message) > 220) or (length($issi) > 8)) {
		return 0;
	}
#	char f[message.length() + issi.length() + 20];
#	sprintf(f, "AT+CMGS=%s,%03d\r\n%s%c",
#						 std::to_string(std::stoi(issi)).c_str(),
#						 (int)message.length() * 4,
#						 message.c_str(), 0x1a);
#	$sds = $f;
	return 1;
}

#xe1xlz eddy moreno

sub createCfmSDS {
	my ($sds, $issi, $msg) = @_;
	
	print color('green'), "createCfmSDS\n", color('reset');
	print "issi $issi\n";
	print "msg $msg\n";
	# To PEI:AT+CMGS=3341010,032
	# 82100045
	my $len = length($msg) * 4;
	for (my $x = 0; $x < 3 ; $x++) {
		if (length($msg) < 3) {
			$msg = "0" . $msg;
		}
	}
	my $f = "AT+CMGS=" . $issi . "," . $len . chr(0x0D) . chr(0x0A) . $msg . chr(0x1A);
	print "f $f\n";
	$_[0] = $f; #$sds = $f;
	return 1;
}

sub createStateSDS {
	my ($sds, $issi) = @_;
	
	if (length($issi) > 8) {
		return 0;
	}
	my $ss;
#	$ss = "821000" << std::setfill('0') << std::setw(sizeof(short)) .
#		 std::hex << getSdsMesgId();

#	my $f[length($issi + length($ss) + 20];
#	sprintf(f, "AT+CMGS=%s,%03d\r\n%s%c",
#						 std::to_string(std::stoi(issi)).c_str(),
#						 (int)ss.str().length() * 4,
#						 ss.str().c_str(), 0x1a);
#	$sds = $f;
	return 1;
}

sub decodeSDS {
	my ($hexSDS) = @_;

	my $sds_text;
	my $ss;
	for (my $a=0; $a < length($hexSDS); $a+=2) {
		$ss = hex(substr($hexSDS, $a, 2));
		$sds_text = $sds_text . chr($ss);
	}
	return $sds_text;
}


sub radians {
	my ($degrees) = @_;

	return ($degrees * pi()) / 180.0;
}


sub degrees {
	my ($radians) = @_;

	return ($radians * 180.0) / pi();
}

####################################################
sub calcDistance {
	my ($lat1, $lon1, $lat2, $lon2) = @_;

	my $dlon = pi() * ($lon2 - $lon1) / 180.0;
	my $dlat = pi() * ($lat2 - $lat1) / 180.0;

	my $a = (sin($dlat / 2) * sin($dlat / 2)) + cos(pi() * $lat1 / 180.0) *
		cos(pi() * $lat2/180) * (sin($dlon / 2) * sin($dlon / 2));
	my $angle = 2 * atan2(sqrt($a), sqrt(1 - $a));
	return (int($angle * RADIUS * 100.0)) / 100.0;
}

####################################################
sub calcBearing {
	my ($lat1, $lon1, $lat2, $lon2) = @_;

	my $teta1 = radians($lat1);
	 my $teta2 = radians($lat2);
	my $delta2 = radians($lon2-$lon1);

	my $y = sin($delta2) * cos($teta2);
	my $x = cos($teta1) * sin($teta2) - sin($teta1) * cos($teta2) * cos($delta2);
	my $br = fmod(degrees(atan2($y, $x)) + 360.0, 360.0);
	return (int($br * 10.)) / 10.;
}

sub getDecimalDegree {
	my ($pos) = @_;
	my $degree = 0.0;
#	$degree = ($pos->deg + ($pos->min + ($pos->sec/60.0))/60.0);
	return $degree;
}


# return the ISSI as part of the TEI
sub getISSI {
	my ($tsi) = @_;

	my $t_issi;
	my $len = length($tsi);
	
	if ($len < 8) {
		$t_issi = "00000000" . $tsi;
#		return $t_issi substr(length(substr($t_issi)) - 8, 8);
	}
	$t_issi = substr($tsi, $len - 8, 8);
	return $t_issi;
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
	$_[1] = int($mcc);
	$_[2] = $mnc;
	$_[3] = $issi;
	return $ret;
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























1;