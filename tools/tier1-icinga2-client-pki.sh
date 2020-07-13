#!/bin/bash

conf_dir=/etc/icinga2
log_dir=/var/log/deploy

mkdir -p ${log_dir}

HOSTNAME=`/bin/hostname -f`
MASTER="icinga12.gridpp.rl.ac.uk";

/bin/ping -q -c1 ${MASTER} &> /dev/null

if [ $? -eq 0 ]; then
echo "pinging...${MASTER}...OK";
else
echo "Not pinging...${MASTER}...Setting MASTER=icinga12.gridpp.rl.ac.uk";
MASTER="icinga11.gridpp.rl.ac.uk";
fi

/bin/ping -q -c1 ${MASTER} &> /dev/null

if [ $? -eq 0 ]; then
echo "pinging...${MASTER}...OK";
else
echo "Not pinging...${MASTER}...Both icinga11.gridpp.rl.ac.uk AND icinga12.gridpp.rl.ac.uk are not pinging..." | tee -a ${log_dir}/tier1-icinga2-client-config;
exit 1;
fi

if [ -f /var/run/icinga2/icinga2.pid ]; then
        echo "$(date +"%d %b %T"): Icinga2 pid file is found...so stopping." | tee -a ${log_dir}/tier1-icinga2-client-config;

        RHRELEASE=`cat /etc/redhat-release |sed -n 's/.*release \(.\).*/\1/p'`
        if [ "$RHRELEASE" == "7"  ]; then
        systemctl stop icinga2
        else
        service icinga2 stop;
        fi

     else
        echo "$(date +"%d %b %T"): Icinga2 is not running..." | tee -a ${log_dir}/tier1-icinga2-client-config;
fi

# Get Ticket

  echo "wget --no-proxy -qO- http://${MASTER}/getTicket.php" >> ${log_dir}/tier1-icinga2-client-config 2>&1;

TICKET=`wget --no-proxy -qO- http://${MASTER}/getTicket.php`

# Check Ticket

if [ -n "$TICKET" ]; then

# Delete exising files.

#rm -rf /etc/icinga2/pki/*
rm -rf /var/lib/icinga2/certs/*

# Run icinga2 pki commands

icinga2 pki new-cert --key /var/lib/icinga2/certs/$HOSTNAME.key --cert /var/lib/icinga2/certs/$HOSTNAME.crt --cn $HOSTNAME >> ${log_dir}/tier1-icinga2-client-config 2>&1;

icinga2 pki save-cert --key /var/lib/icinga2/certs/$HOSTNAME.key --cert /var/lib/icinga2/certs/$HOSTNAME.crt --trustedcert /var/lib/icinga2/certs/trusted-master.crt --host ${MASTER} >> ${log_dir}/tier1-icinga2-client-config 2>&1;

icinga2 pki request --key /var/lib/icinga2/certs/$HOSTNAME.key --cert /var/lib/icinga2/certs/$HOSTNAME.crt --trustedcert /var/lib/icinga2/certs/trusted-master.crt --host ${MASTER} --ca /var/lib/icinga2/certs/ca.crt --ticket $TICKET >> ${log_dir}/tier1-icinga2-client-config 2>&1;

# Enable api feature

icinga2 feature enable api >> ${log_dir}/tier1-icinga2-client-config 2>&1;

echo "Done: icinga2 client pki is setup properly..." | tee -a ${log_dir}/tier1-icinga2-client-config;

echo "you need to run service icinga2 start now." | tee -a ${log_dir}/tier1-icinga2-client-config;

 else

# if can't get Ticket
echo "Failed: wget --no-proxy -qO- http://${MASTER}/getTicket.php" | tee -a ${log_dir}/tier1-icinga2-client-config;
echo "run following command on ${MASTER} to generate ticket."          | tee -a ${log_dir}/tier1-icinga2-client-config;
echo "icinga2 pki ticket --cn $HOSTNAME"                           | tee -a ${log_dir}/tier1-icinga2-client-config;

echo "
after getting ticket now run following commands...

icinga2 pki new-cert  --key /var/lib/icinga2/certs/$HOSTNAME.key --cert /var/lib/icinga2/certs/$HOSTNAME.crt --cn $HOSTNAME

icinga2 pki save-cert --key /var/lib/icinga2/certs/$HOSTNAME.key --cert /var/lib/icinga2/certs/$HOSTNAME.crt --trustedcert /var/lib/icinga2/certs/trusted-master.crt --host ${MASTER}

icinga2 pki request   --key /var/lib/icinga2/certs/$HOSTNAME.key --cert /var/lib/icinga2/certs/$HOSTNAME.crt --trustedcert /var/lib/icinga2/certs/trusted-master.crt --host ${MASTER} --ca /var/lib/icinga2/certs/ca.crt --ticket TICKET Here

icinga2 feature enable api" | tee -a ${log_dir}/tier1-icinga2-client-config 2>&1;

fi
