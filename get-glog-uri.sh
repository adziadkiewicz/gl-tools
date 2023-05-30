#!/bin/sh
#PATH:/usr/local/sbin/get-glog-uri.sh
cat /etc/graylog/server/server.conf | grep http_bind_address | cut -d ' ' -f 3