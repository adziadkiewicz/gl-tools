#!/bin/sh
#
# This script will be executed *after* all the other init scripts.
# You can put your own initialization stuff in here if you don't
# want to do the full Sys V style init stuff.
sleep 2
/usr/bin/chvt 13
plymouth quit
if [ -f "/root/FIRSTBOOT" ]
then
    echo "==================================================="
    echo " KROK (1) HASLO ADMINISTRATORA APPLIANCE "
    echo "==================================================="
    echo ""
    echo -n "Podaj haslo uzytkownika root"
    echo ""
    echo -n "Wywoluje komende 'passwd root' ... "
    echo ""
    echo -n "UWAGA: Znaki nie sa widoczne!"
    echo ""
    passwd root
    echo ""
    echo ""
    echo "==================================================="
    echo " KROK (2) - NAZWA SERWERA "
    echo "==================================================="
    echo ""
    echo -n "Wpisz nazwe serwera             : "
    read -n50 -e NAME
        echo -n "Wpisz nazwe domeny serwera      : "
    read -n50 -e DOMAIN
    echo ""
    echo ""
        FQDN="${NAME}.${DOMAIN}"
    echo "==================================================="
    echo " KROK (3) - USTAWIENIA SIECIOWE"
    echo "==================================================="
    echo ""
    echo -n "Wprowadz adres IP : "
    read -n50 -e IP
        while [[ $(ipcalc -cs $IP && echo "vail_ip" || echo "invalid_ip") == "invalid_ip" ]]
        do
                echo "To nie jest poprawny adres IP\!"
                echo "Wprowadz ponownie adres IP :"
                read -n50 -e IP
        done

    echo -n "Wprowadz maske podsieci : "
    read -n50 -e NETMASK
        while [[ $(ipcalc -cs $NETMASK && echo "vail_ip" || echo "invalid_ip") = "invalid_ip" ]]
        do
                echo "To nie jest poprawny adres maski\!"
                echo -n "Wprowadz ponownie maske podsieci :"
                read -n50 -e NETMASK
        done

        echo -n "Wprowadz adres IP bramy : "
    read -n50 -e GATEWAY
        while [[ $(ipcalc -cs $GATEWAY && echo "vail_ip" || echo "invalid_ip") = "invalid_ip" ]]
        do
                echo "To nie jest poprawny adres IP\!"
                echo -n "Wprowadz ponownie adres IP bramy:"
                read -n50 -e GATEWAY
        done

    echo -n "Wprowadz adres IP serwera DNS : "
    read -n50 -e DNS
        while [[ $(ipcalc -cs $DNS && echo "vail_ip" || echo "invalid_ip") = "invalid_ip" ]]
        do
                echo "To nie jest poprawny adres IP\!"
                echo -n "Wprowadz ponownie adres IP serwera DNS :"
                read -n50 -e DNS
        done

    echo ""
    echo ""
    echo "==================================================="
    echo " KROK (4) - USTAWIENIA APLIKACJI"
    echo "==================================================="
    echo ""
    echo -n "Podaj haslo dla uzytkownika admin (Graylog/Zabbix/Grafana GUI)"
    echo ""
    echo -n "  UWAGA: znaki nie sa widoczne!"
    echo ""
    echo -n "Haslo: "
    read -n50 -s ADMINPASS
    echo ""
    echo ""
    echo "==================================================="
    echo "Czy wprowadzone dane sa poprawne ? (t/n) : "
    echo ""
    read -n1 -e answer
    if [ $answer == t ]
    then
        # change hostname
        echo "$NAME" > /etc/hostname
        sed -i '/HOSTNAME/c\' /etc/sysconfig/network
        echo "HOSTNAME=$NAME" >> /etc/sysconfig/network
        hostname $NAME
        # Remove UUID
        sed -i '/UUID/c\' /etc/sysconfig/network-scripts/ifcfg-eth0

        #change Bootproto:
        sed -i '/BOOTPROTO/c\' /etc/sysconfig/network-scripts/ifcfg-eth0
        echo "BOOTPROTO=static" >> /etc/sysconfig/network-scripts/ifcfg-eth0

        #change IP address:
        sed -i '/IPADDR/c\' /etc/sysconfig/network-scripts/ifcfg-eth0
        echo "IPADDR=$IP" >> /etc/sysconfig/network-scripts/ifcfg-eth0

        # change netmask
        sed -i '/NETMASK/c\' /etc/sysconfig/network-scripts/ifcfg-eth0
        echo "NETMASK=$NETMASK" >> /etc/sysconfig/network-scripts/ifcfg-eth0

        # change gateway
        sed -i '/GATEWAY/c\' /etc/sysconfig/network-scripts/ifcfg-eth0
        echo "GATEWAY=$GATEWAY" >> /etc/sysconfig/network-scripts/ifcfg-eth0

        # change dns
        sed -i '/DNS/c\' /etc/sysconfig/network-scripts/ifcfg-eth0
        echo "DNS1=$DNS" >> /etc/sysconfig/network-scripts/ifcfg-eth0
        sed -i '/nameserver/c\' /etc/resolv.conf
        sed -i '/search/c\' /etc/resolv.conf
        echo "nameserver $DNS" >> /etc/resolv.conf
        echo "search $DOMAIN" >> /etc/resolv.conf

        # change MAC
        MAC=`/sbin/ifconfig | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`
        sed -i '/HWADDR/c\' /etc/sysconfig/network-scripts/ifcfg-eth0
        echo "HWADDR=$MAC" >> /etc/sysconfig/network-scripts/ifcfg-eth0
        # make the interface up and restart the service
        echo ""
        echo ""
        echo "Restartuje Network Service . . ."
        service network restart &> /dev/null
        echo ""
        echo ""
        echo "Prosze zweryfikowac wprowadzone zmiany:"
        echo ""
        echo ""
        echo "Nazwa hosta jest ustawiona jako: `hostname`"
        echo ""
        echo "Wynik dzialania komendy ifconfig:"
        echo "==================================================="
        ifconfig eth0
        echo "==================================================="

        # configure apps
        echo "Konfiguruje uslugi aplikacji . . ."
        echo ""
        echo ""
        sed -i '/http_bind_address/c\' /etc/graylog/server/server.conf
        echo "http_bind_address = $IP:9000" >> /etc/graylog/server/server.conf

	# Graylog
	PASSWORD=$(echo -n $ADMINPASS | sha256sum | awk '{print $1}')
        sed -i '/root_password_sha2/c\' /etc/graylog/server/server.conf
        echo "root_password_sha2 = $PASSWORD" >> /etc/graylog/server/server.conf

	# Zabbix
	mysql zabbix -e "update users set passwd=md5('${ADMINPASS}') where alias='admin';"

        echo "   - tworze certyfikat Graylog SSL . . ."
        echo ""
        echo ""
        # self cert
	CNFFILE='/etc/ssl/app-ssl.cnf'
        echo "[req]" > "${CNFFILE}"
        echo "req_extensions = v3_req" >> "${CNFFILE}" 
        echo "distinguished_name = req_distinguished_name" >> "${CNFFILE}"
        echo "prompt = no" >> "${CNFFILE}"

        echo "[req_distinguished_name]" >> "${CNFFILE}"
        echo "C = PL" >> "${CNFFILE}"
        echo "ST = slaskie" >> "${CNFFILE}"
        echo "L = Katowice" >> "${CNFFILE}"
        echo "O = Salutaris Sp. z o.o." >> "${CNFFILE}"
        echo "OU = IT" >> "${CNFFILE}"
        echo "CN = $FQDN" >> "${CNFFILE}"

        echo "[v3_req]" >> "${CNFFILE}"
        echo "keyUsage = digitalSignature, keyEncipherment" >> "${CNFFILE}"
        echo "extendedKeyUsage = serverAuth" >> "${CNFFILE}"
        echo "subjectAltName = @alt_names" >> "${CNFFILE}"

        echo "[alt_names]" >> "${CNFFILE}"
        echo "DNS.1=$FQDN" >> "${CNFFILE}"
        echo "IP.1=$IP" >> "${CNFFILE}"

	CERTNAME='app-ssl'
        /usr/bin/openssl req -x509 -days 7300 -newkey rsa:4096 -nodes -keyout /etc/pki/tls/private/${CERTNAME}-key.pem -out /etc/pki/tls/certs/${CERTNAME}-cert.pem -config ${CNFFILE} -extensions v3_req
        /usr/bin/keytool -delete -noprompt -alias glog-ssl-self -keystore /etc/pki/tls/jvm/glog-ssl.jks -storepass changeit
        /usr/bin/keytool -importcert -noprompt -keystore /etc/pki/tls/jvm/glog-ssl.jks -storepass changeit -alias glog-ssl-self -file /etc/pki/tls/certs/${CERTNAME}-cert.pem


        #httpd-apache
        echo "RedirectMatch ^/$ https://$IP:9000/" > /etc/httpd/conf.d/0000-graylog.conf

        echo "Sprzatanie . . . "
        echo ""
        echo ""
        rm -f /root/FIRSTBOOT
        mv -f /root/FIRSTBOOT.sh /etc/salutaris/
        systemctl disable appliance-firstboot.service
        systemctl enable graylog-server.service
        systemctl enable zabbix-server.service
	systemctl enable zabbix-agent.service
        systemctl enable grafana-server.service
        systemctl enable elasticsearch.service
        systemctl enable mongod.service

	rm /etc/ssh/ssh_host_*

        # configure banner
        /sbin/ifup-local

        echo "Kopia zapasowa skryptu FIRSTBOOT.sh zostala utworzona w /etc/salutaris"
        echo ""
        echo ""
        echo "Wykonuje restart serwera (5s) ..."
        sleep 5
        reboot
    else
        bash /root/FIRSTBOOT.sh
    fi
fi

