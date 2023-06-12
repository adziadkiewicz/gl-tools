#!/bin/bash
#
# This script will be executed *after* all the other init scripts.
# You can put your own initialization stuff in here if you don't
# want to do the full Sys V style init stuff.

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

if [ -f "/root/FIRSTBOOT" ]
then
    #sleep 2
    #/usr/bin/chvt 13
    #plymouth quit

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

    #while [[ $((echo "$NAME" | grep -Eq  $validate) && echo "matched" || echo "notmatch") == "notmatch"  ]]
    #do
    #    echo "To nie jest poprawna nazwa\!"
    #    echo -n "Wprowadz ponownie nazwe serwera :"
    #    read -n60 -e NAME
    #done

    echo -n "Wpisz nazwe domeny serwera             : "
    read -n60 -e DOMAIN

    #while [[ $((echo "$DOMAIN" | grep -Eq  $validate) && echo "matched" || echo "notmatch") == "notmatch"  ]]
    #do
    #    echo "To nie jest poprawna nazwa\!"
    #    echo -n "Wprowadz ponownie nazwe serwera :"
    #    read -n60 -e DOMAIN
    #done

    echo ""
    echo ""
    FQDN="${NAME}.${DOMAIN}"

    echo "==================================================="
    echo " KROK (4) - USTAWIENIA SIECIOWE"
    echo "==================================================="
    echo ""
    echo -n "Wprowadz adres IP : "
    read -n50 -e IP
    if ! valid_ip $IP
    then
     while true
     do
      if valid_ip $IP
      then
       break
      fi
      echo "To nie jest poprawny adres IP\!"
      echo "Wprowadz ponownie adres IP :"
      read -n50 -e IP
     done
    fi
	
    echo -n "Wprowadz maske podsieci : "
    read -n50 -e NETMASK
    if ! valid_ip $NETMASK
    then
     while true
     do
      if valid_ip $NETMASK
      then
       break
      fi
      echo "To nie jest poprawny adres \!"
      echo -n "Wprowadz ponownie:"
      read -n50 -e NETMASK
     done
    fi
	
    echo -n "Wprowadz adres IP bramy : "
    read -n50 -e GATEWAY
    if ! valid_ip $GATEWAY
    then
     while true
     do
      if valid_ip $GATEWAY
      then
       break
      fi
      echo "To nie jest poprawny adres\!"
      echo -n "Wprowadz ponownie:"
      read -n50 -e GATEWAY
     done
    fi
	
    echo -n "Wprowadz adres IP serwera DNS : "
    read -n50 -e DNS
    if ! valid_ip $DNS
    then
     while true
     do
      if valid_ip $DNS
      then
       break
      fi
      echo "To nie jest poprawny adres\!"
      echo "Wprowadz ponownie:"
      read -n50 -e DNS
     done
    fi
	
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
	echo "(nacisnij n aby powtorzyc konfiguracje)"
    echo ""
    read -n1 -e answer
    if [ $answer == t ]
    then
        # change hostname
        echo "$NAME" > /etc/hostname
        /bin/hostname -b $NAME

                CIDR=`awk -F. '{
         split($0, octets)
         for (i in octets) {
           mask += 8 - log(2**8 - octets[i])/log(2);
        }
        print "/" mask
                }' <<< $NETMASK`


        rm -rf /etc/netplan/00-installer-config.yaml
                echo "network:" > /etc/netplan/00-glog-network.yaml
        echo "    ethernets:" >> /etc/netplan/00-glog-network.yaml
        echo "        ens192:" >> /etc/netplan/00-glog-network.yaml
        echo "            dhcp4: false" >> /etc/netplan/00-glog-network.yaml
        echo "            addresses: [$IP$CIDR]" >> /etc/netplan/00-glog-network.yaml
        echo "            nameservers:" >> /etc/netplan/00-glog-network.yaml
        echo "                addresses: [$DNS]" >> /etc/netplan/00-glog-network.yaml
        echo "            routes:" >> /etc/netplan/00-glog-network.yaml
                echo "                - to: default" >> /etc/netplan/00-glog-network.yaml
                echo "                  via: $GATEWAY" >> /etc/netplan/00-glog-network.yaml
                echo "    version: 2" >> /etc/netplan/00-glog-network.yaml


        # make the interface up and restart the service
        echo ""
        echo ""
        echo "Restartuje Network Service . . ."
        /sbin/netplan apply &> /dev/null
        echo ""
        echo ""
        echo "Prosze zweryfikowac wprowadzone zmiany:"
        echo ""
        echo ""
        echo "Nazwa hosta jest ustawiona jako: `hostname`"
        echo ""
        echo "Wynik dzialania komendy ifconfig:"
        echo "==================================================="
        ifconfig ens192
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

        sed -i '/transport_email_web_interface_url/c\' /etc/graylog/server/server.conf
        echo "transport_email_web_interface_url = https://$IP:9000"

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
        /usr/bin/openssl req -x509 -days 7300 -newkey rsa:4096 -nodes -keyout /etc/ssl/glog/${CERTNAME}-key.pem -out /etc/ssl/glog/${CERTNAME}-cert.pem -config ${CNFFILE} -extensions v3_req
        /usr/bin/keytool -delete -noprompt -alias glog-ssl-self -keystore /etc/ssl/certs/java/glog-ssl.jks -storepass changeit
        /usr/bin/keytool -importcert -noprompt -keystore /etc/ssl/certs/java/glog-ssl.jks -storepass changeit -alias glog-ssl-self -file /etc/ssl/glog/${CERTNAME}-cert.pem

        chmod 0644 /etc/ssl/glog/${CERTNAME}-cert.pem
        chmod 0640 /etc/ssl/glog/${CERTNAME}-key.pem

        echo "Sprzatanie . . . "
        echo ""
        echo ""
        rm -f /root/FIRSTBOOT
        mv -f /root/FIRSTBOOT.sh /etc/glog-appliance/
        systemctl disable appliance-firstboot.service
        systemctl enable graylog-server.service
        systemctl enable opensearch.service
        systemctl enable mongod.service

        rm -rf /etc/ssh/ssh_host_*
        echo "Nowe certyfikaty SSH . . . "
        /usr/sbin/dpkg-reconfigure openssh-server

        echo "Konfiguracja dla skryptow . . ."
        /usr/local/sbin/glog-create-config.py -gh ${IP} -gp 9000 -gP https -gt `cat /etc/glog-appliance/tokens/admin-api-token` -eh localhost -ep 9200 -eP http -er glog-arch -af /var/log/glog-arch.log

        echo "Uruchamiam uslugi . . ."
        echo ""
        systemctl start mongod.service
                sleep 5
                systemctl status mongod.service --no-pager
                sleep 5
                systemctl start opensearch.service
                sleep 5
                systemctl status opensearch.service --no-pager
                sleep 5
                systemctl start graylog-server.service
                sleep 60
                systemctl status graylog-server.service --no-pager
                sleep 30

                echo "Tworze token uzytkownika graylog-sidecar . . ."
                /usr/local/sbin/glog-create-token.py -n sidecar-api-token -u graylog-sidecar -f /etc/glog-appliance/tokens/sidecar-api-token

                echo "Zabezpieczam plik z tokenem . . ."
        chmod 0400 /etc/glog-appliance/tokens/sidecar-api-token

                echo "Tworze paczke instalacyjna dla Windows . . ."
                TOKEN=`cat /etc/glog-appliance/tokens/sidecar-api-token`
        GLOGURIAPI="https://`/usr/local/sbin/get-glog-uri.sh`/api"
        GLOGURIAPI_="${GLOGURIAPI/\/\//\^\/\^\/}"

        echo "@echo off" > /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "REM Skrypt instalujący agenta Graylog dla systemów Windows" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "REM (c) 2017 AD, Salutaris Sp. z o.o." >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "REM v 4.1" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "REM" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "REM Dopasowane do wersji 3.0 skryptu oraz Graylog 3.x" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "cd /D \"%~dp0\"" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "glog-win-agent-install-beats.bat -token $TOKEN -url $GLOGURIAPI_ -glsver 1.4.0-1" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat
        echo "" >> /var/www/glog-download/win/AUTO-glog-win-agent-BEATS.bat


        echo "server_url: \"$GLOGURIAPI\"" > /var/www/glog-download/linux/sidecar.yml
        echo "server_api_token: \"$TOKEN\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "node_id: \"file:/etc/graylog/sidecar/node-id\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "node_name: \"\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "update_interval: 10" >> /var/www/glog-download/linux/sidecar.yml
        echo "tls_skip_verify: true" >> /var/www/glog-download/linux/sidecar.yml
        echo "send_status: true" >> /var/www/glog-download/linux/sidecar.yml
        echo "Default:" >> /var/www/glog-download/linux/sidecar.yml
        echo "collector_binaries_whitelist:" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/bin/filebeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/bin/packetbeat\"" >> /var/www/glog-download/linux/sidecar.yml 
        echo "  - \"/usr/bin/metricbeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/bin/heartbeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/bin/auditbeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/bin/journalbeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/share/filebeat/bin/filebeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/share/packetbeat/bin/packetbeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/share/metricbeat/bin/metricbeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/share/heartbeat/bin/heartbeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/share/auditbeat/bin/auditbeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/share/journalbeat/bin/journalbeat\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/usr/bin/nxlog\"" >> /var/www/glog-download/linux/sidecar.yml
        echo "  - \"/opt/nxlog/bin/nxlog\"">> /var/www/glog-download/linux/sidecar.yml

        cp -f /var/www/glog-download/linux/sidecar.yml /etc/graylog/sidecar/sidecar.yml 
        systemctl enable graylog-sidecar
		systemctl restart graylog-sidecar
		
		/usr/bin/unix2dos /var/www/glog-download/win/*.bat
        rm -rf /var/www/glog-download/win/win-1.4.0-1.zip
        cd /var/www/glog-download/win
        /usr/bin/zip win-1.4.0-1.zip AUTO-glog-win-agent-BEATS.bat glog-win-agent-install-beats.bat graylog_sidecar_installer_1.4.0-1.exe

        chown -R www-data:www-data /var/www/glog-download/

        echo "Ustawiam zmienne systemu Graylog . . ."
        /usr/local/sbin/glog-create-var.py -n glog_server_ip -d 'Graylog Server IP' -c "$IP"
        /usr/local/sbin/glog-create-var.py -n glog_server_fqdn -d 'Graylog Server FQDN' -c "$FQDN"

        echo "Kopia zapasowa skryptu FIRSTBOOT.sh zostala utworzona w /etc/glog-appliance/"
        echo ""
        echo ""
        echo "Wykonuje restart serwera (5s) ..."
        sleep 5
        reboot
    else
        /bin/bash /root/FIRSTBOOT.sh
    fi
fi

exit 0
