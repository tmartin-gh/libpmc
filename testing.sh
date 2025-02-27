#!/bin/bash -e
# SPDX-License-Identifier: GPL-3.0-or-later
#
# @author Erez Geva <ErezGeva2@@gmail.com>
# @copyright 2021 Erez Geva
# @copyright GNU General Public License 3.0 or later
#
# testing script
###############################################################################
main()
{
 local file
 # Default values
 local -r def_ifName=enp0s25
 local -r def_cfgFile=/etc/linuxptp/ptp4l.conf
 local -r def_linuxptpLoc=../linuxptp
 ##############################################################################
 while getopts 'i:c:l:' opt; do
   case $opt in
     i)
       local -r ifName="$OPTARG"
       ;;
     c)
       local -r cfgFile="$OPTARG"
       ;;
     l)
       local -r linuxptpLoc="$OPTARG"
       ;;
   esac
 done
 for n in ifName cfgFile linuxptpLoc; do
   local -n var=$n
   [ -n "$var" ] || eval "local -r $n=\"\$def_$n\""
 done
 ##############################################################################
 local -r uds="$linuxptpLoc/uds.c"
 if [ -d "$linuxptpLoc" -a -f "$uds" ]; then
   # Add all users for testing (so we can test without using root :-)
   local -r reg='^#define UDS_FILEMODE'
   if [ -n "$(grep "$reg.*GRP)" "$uds")" ];then
     sed -i "/$reg/ s#GRP).*#GRP|S_IROTH|S_IWOTH)#" "$uds"
   fi
   make --no-print-directory -j -C "$linuxptpLoc"
   local -r pmctool="sudo \"$linuxptpLoc/pmc\""
 else
   local -r useSudo="sudo"
   local -r pmctool="sudo /usr/sbin/pmc"
 fi
 ##############################################################################
 # script languages source
 local -r mach=$(uname -m)
 local -r fmach="/$mach*"
 getFirstFile "/usr/lib$fmach/libpmc.so"
 if [ ! -f "$file" ]; then
   local -r ldPath='LD_LIBRARY_PATH=..'
 fi
 local ldPathRuby ldPathPhp needCmp needLua needPython1 needPython2 needPython3
 local phpIni
 probeLibs
 needCmp="$needCmp$needPython2$needPython3"
 ##############################################################################
 local -r instPmcLib=/usr/sbin/pmc.lib
 if [ -x $instPmcLib ]; then
   local -r pmclibtool=$instPmcLib
 else
   local -r pmclibtool=./pmc
 fi
 ##############################################################################
 if [ "$pmclibtool" != "$instPmcLib" -o -n "$ldPath$needCmp$needLua" ]; then
   printf " * build libpmc\n"
   time make -j
 fi
 if [ -z "$(pgrep ptp4l)" ]; then
   printf "\n * Run ptp daemon:\n   cd \"$(realpath $linuxptpLoc)\" %s\n\n"\
          "&& make && sudo ./ptp4l -f $cfgFile -i $ifName"
   return
 fi
 ##############################################################################
 # compare linuxptp-pmc with libpmc-pmc dump
 local -r t1=$(mktemp linuxptp.XXXXXXXXXX) t2=$(mktemp libpmc.tool.XXXXXXXXXX)
 local n cmds
 # all TLVs that are supported by linuxptp ptp4l
 local -r tlvs='ANNOUNCE_RECEIPT_TIMEOUT CLOCK_ACCURACY CLOCK_DESCRIPTION
   CURRENT_DATA_SET DEFAULT_DATA_SET DELAY_MECHANISM DOMAIN
   LOG_ANNOUNCE_INTERVAL LOG_MIN_PDELAY_REQ_INTERVAL LOG_SYNC_INTERVAL
   PARENT_DATA_SET PRIORITY1 PRIORITY2 SLAVE_ONLY TIMESCALE_PROPERTIES
   TIME_PROPERTIES_DATA_SET TRACEABILITY_PROPERTIES USER_DESCRIPTION
   VERSION_NUMBER PORT_DATA_SET
   TIME_STATUS_NP GRANDMASTER_SETTINGS_NP PORT_DATA_SET_NP PORT_PROPERTIES_NP
   PORT_STATS_NP SUBSCRIBE_EVENTS_NP SYNCHRONIZATION_UNCERTAIN_NP'
 # Planned: MASTER_ONLY
 local -r setmsg="set PRIORITY2 137"
 local -r verify="get PRIORITY2"
 for n in $tlvs; do cmds+=" \"get $n\"";done

 printf "\n * Make $t1 using linuxptp pmc\n"
 eval "$pmctool -u -f $cfgFile \"$setmsg\"" > $t1
 eval "$pmctool -u -f $cfgFile \"$verify\"" >> $t1
 time eval "$pmctool -u -f $cfgFile $cmds" | grep -v ^sending: >> $t1

 # real  0m0.113s
 # user  0m0.009s
 # sys   0m0.002s

 printf "\n * Make $t2 using libpmc\n"
 eval "$useSudo $pmclibtool -u -f $cfgFile \"$setmsg\"" > $t2
 eval "$useSudo $pmclibtool -u -f $cfgFile \"$verify\"" >> $t2
 time eval "$useSudo $pmclibtool -u -f $cfgFile $cmds" | grep -v ^sending: >> $t2

 # real  0m0.019s
 # user  0m0.004s
 # sys   0m0.011s

 printf "\n * We expect 'protocolAddress' and 'timeSource' difference\n%s\n\n"\
          " * Statistics may apprear"
 cmd diff $t1 $t2 | grep '^[0-9-]' -v
 rm $t1 $t2

 ##############################################################################
 # Test script languages wrappers
 local -r t3=$(mktemp script.XXXXXXXXXX)
 # Expected output of testing scripts
 local -r scriptOut=\
"Use configuration file $cfgFile
Get reply for USER_DESCRIPTION
get user desc:
physicalAddress: f1:f2:f3:f4
physicalAddress: f1f2f3f4
clk.physicalAddress: f1:f2:f3:f4
clk.physicalAddress: f1f2f3f4
manufacturerIdentity: 00:00:00
revisionData: This is a test
set new priority 147 success
Get reply for PRIORITY1
priority1: 147
set new priority 153 success
Get reply for PRIORITY1
priority1: 153
"
 enter perl
 time eval "$ldPath $useSudo ./test.pl $cfgFile" > ../$t3
 cd ..
 printf "\n * We except real 'user desc' on '>'\n"
 diff <(printf "$scriptOut") $t3 | grep '^[0-9-]' -v
 enter ruby
 time eval "$ldPathRuby $useSudo ./test.rb $cfgFile" | diff - ../$t3
 cd ..
 enter lua
 local i
 for i in 1 2 3; do
   printf "\n lua 5.$i ---- \n"
   if [ -n "$needLua" ]; then
     ln -sf 5.$i/pmc.so
   else
     rm -f pmc.so
   fi
   time eval "$ldPath $useSudo lua5.$i ./test.lua $cfgFile" | diff - ../$t3
 done
 cd ..
 enter python
 for i in 2 3; do
   rm -rf pmc.pyc __pycache__
   local -n need=needPython$i
   if [ -n "$need" ]; then
     ln -sf $i/_pmc.so
   else
     rm -f _pmc.so
   fi
   printf "\n $(readlink $(which python$i)) ---- \n"
   eval "$ldPath $useSudo python$i ./test.py $cfgFile" > /dev/null
   time eval "$ldPath $useSudo python$i ./test.py $cfgFile" | diff - ../$t3
 done
 cd ..
 enter php
 [ -z "$phpIni" ] || ./php_ini.sh
 time eval "$ldPathPhp $useSudo ./test.php $cfgFile" | diff - ../$t3
 cd ..
 rm $t3
}
###############################################################################
enter()
{
 cd $1
 printf "\n =====  Run $1  ===== \n"
}
cmd()
{
 echo $@
 $@
}
getFirstFile()
{
 local f
 for f in $@; do
   if [ -f "$f" ]; then
     file="$f"
     return
   fi
 done
 file=''
}
probeLibs()
{
 getFirstFile "/usr/lib$fmach/perl*/*/auto/PmcLib/PmcLib.so"
 if [ ! -f "$file" ]; then
   needCmp=y
 fi
 local i
 for i in 1 2 3; do
   getFirstFile "/usr/lib$fmach/lua/5.$i/pmc.so"
   if [ ! -f "$file" ]; then
     needLua=y
   fi
   getFirstFile "/usr/lib/python$i*/dist-packages/_pmc.*$mach*.so"
   if [ ! -f "$file" ]; then
     local -n need=needPython$i
     need=y
   fi
 done
 ldPathRuby=$ldPath
 file="$(ruby -rrbconfig -e 'puts RbConfig::CONFIG["vendorarchdir"]')/pmc.so"
 if [ ! -f "$file" ]; then
   needCmp=y
   ldPathRuby+=" RUBYLIB=."
 fi
 ldPathPhp=$ldPath
 if [ ! -f "$(php-config --extension-dir)/pmc.so" ]; then
   needCmp=y
   phpIni=y
   ldPathPhp+=" PHPRC=."
 fi
}
###############################################################################
main $@

manual()
{
 # Test network layer sockets on real target
net=enp7s0 ; pmc -i $net -f /etc/linuxptp/ptp4l.$net.conf "get CLOCK_DESCRIPTION"
 # Using UDS
net=enp7s0 ; pmc -u -f /etc/linuxptp/ptp4l.$net.conf "get CLOCK_DESCRIPTION"
}
