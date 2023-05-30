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
    echo "======================================================="
    echo " KROK (1) HASLO ADMINISTRATORA LINUX - root "
    echo "======================================================="
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
	
    echo "======================================================="
    echo " KROK (2) HASLO ADMINISTRATORA LINUX - gl-app (sudoer)"
    echo "======================================================="
    echo ""
    echo ""
    echo -n "Podaj haslo uzytkownika gl-app"
    echo ""
    echo -n "Wywoluje komende 'passwd gl-app' ... "
    echo ""
    echo -n "UWAGA: Znaki nie sa widoczne!"
    echo ""
    passwd gl-app
    echo ""
    echo ""
   
    echo "==================================================="
    echo " KROK (3) - NAZWA SERWERA I DOMENY"
    echo "==================================================="
    echo ""
    validate="^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-\_]*[a-zA-Z0-9])$"
    echo -n "Wpisz nazwe serwera             : "
    read -n60 -e NAME

    while [[ $((echo "$NAME" | grep -Eq  $validate) && echo "matched" || echo "notmatch") == "notmatch"  ]]
    do
        echo "To nie jest poprawna nazwa\!"
        echo -n "Wprowadz ponownie nazwe serwera :"
        read -n60 -e NAME
    done

    echo -n "Wpisz nazwe domeny serwera             : "
    read -n60 -e DOMAIN

    while [[ $((echo "$DOMAIN" | grep -Eq  $validate) && echo "matched" || echo "notmatch") == "notmatch"  ]]
    do
        echo "To nie jest poprawna nazwa\!"
        echo -n "Wprowadz ponownie nazwe serwera :"
        read -n60 -e DOMAIN
    done

    echo ""
    echo ""
    FQDN="${NAME}.${DOMAIN}"
	
    echo "==================================================="
    echo " KROK (4) - USTAWIENIA SIECIOWE"
    echo "==================================================="
    echo ""
    echo -n "Wprowadz adres IP : "
    read -n50 -e IP
    while [[ $(/bin/ipcalc -cs $IP && echo "vail_ip" || echo "invalid_ip") == "invalid_ip" ]]
    do
        echo "To nie jest poprawny adres IP\!"
        echo "Wprowadz ponownie adres IP :"
        read -n50 -e IP
    done

    echo -n "Wprowadz maske podsieci : "
    read -n50 -e NETMASK
    while [[ $(/bin/ipcalc -cs $NETMASK && echo "vail_ip" || echo "invalid_ip") == "invalid_ip" ]]
    do
        echo "To nie jest poprawny adres maski\!"
        echo -n "Wprowadz ponownie maske podsieci :"
        read -n50 -e NETMASK
    done

    echo -n "Wprowadz adres IP bramy : "
    read -n50 -e GATEWAY
    while [[ $(/bin/ipcalc -cs $GATEWAY && echo "vail_ip" || echo "invalid_ip") == "invalid_ip" ]]
    do
        echo "To nie jest poprawny adres IP\!"
        echo -n "Wprowadz ponownie adres IP bramy:"
        read -n50 -e GATEWAY
    done

    echo -n "Wprowadz adres IP serwera DNS : "
    read -n50 -e DNS
    while [[ $(/bin/ipcalc -cs $DNS && echo "vail_ip" || echo "invalid_ip") == "invalid_ip" ]]
    do
        echo "To nie jest poprawny adres IP\!"
        echo -n "Wprowadz ponownie adres IP serwera DNS :"
        read -n50 -e DNS
    done

    echo ""
    echo ""
    echo "==================================================="
    echo " KROK (5) - USTAWIENIA APLIKACJI"
    echo "==================================================="
    echo ""
    echo -n "Podaj haslo dla uzytkownika admin (Graylog GUI)"
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
        /bin/hostname -b $NAME
 
        rm -rf /etc/netplan/00-installer-config.yaml
		echo "network:" > /etc/netplan/00-glog-network.yaml
        echo "    ethernets:" >> /etc/netplan/00-glog-network.yaml
        echo "        eth0:" >> /etc/netplan/00-glog-network.yaml
        echo "            dhcp4: false" >> /etc/netplan/00-glog-network.yaml
        echo "            addresses: [$IP/$NETMASK]" >> /etc/netplan/00-glog-network.yaml
        echo "            gateway4: $GATEWAY" >> /etc/netplan/00-glog-network.yaml
        echo "            nameservers:" >> /etc/netplan/00-glog-network.yaml
        echo "                addresses: [$DNS]" >> /etc/netplan/00-glog-network.yaml
        echo "    version: 2" >> /etc/netplan/00-glog-network.yaml

        # make the interface up and restart the service
        echo ""
        echo ""
        echo "Restartuje Network Service . . ."
        service /bin/systemctl status systemd-networkd.service &> /dev/null
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

        echo "Sprzatanie . . . "
        echo ""
        echo ""
        rm -f /root/FIRSTBOOT
        mv -f /root/FIRSTBOOT.sh /etc/salutaris/
        systemctl disable appliance-firstboot.service
        systemctl enable graylog-server.service
        systemctl enable opensearch.service
        systemctl enable mongod.service

	    rm -rf /etc/ssh/ssh_host_*

        # configure banner
        /sbin/ifup-local

        echo "Kopia zapasowa skryptu FIRSTBOOT.sh zostala utworzona w /etc/salutaris"
        echo ""
        echo ""
        echo "Wykonuje restart serwera (5s) ..."
        sleep 5
        reboot
    else
        /bin/bash /root/FIRSTBOOT.sh
    fi
fi

