#!/usr/bin/env python3

#
# skrypt opracowany w ramach wdrozenia centralnego systemu syslog
# (c) 2023, AD, Salutaris Sp. z o.o.
#
# v1.0
#


import requests
import json
import subprocess
import time
import logging
import sys
import getopt
import argparse
import urllib3

def query_yes_no(question, default="yes"):

        valid = {"yes": True, "y": True, "ye": True, "t": True, "tak": True, "no": False, "n": False, "nie":False}

        if default is None:
                prompt = " [t/n] "
        elif default == "yes":
                prompt = " [T/n] "
        elif default == "no":
                prompt = " [t/N] "
        else:
                raise ValueError("Nieprawidlowa domyslna wartosc odpowiedzi : '%s'" % default)

        while True:
                sys.stdout.write(question + prompt)
                choice = str(input()).lower()
                if default is not None and choice == '':
                        return valid[default]
                elif choice in valid:
                        return valid[choice]
                else:
                        sys.stdout.write("Wpisz 'tak' lub 'nie' (lub 't' albo 'n').\n")

def try_parseDate(s, fmts):
        for fmt in fmts:
                try:
                        return datetime.strptime(s, fmt)
                except:
                        continue

                return None

def time_in_range(start, end, x):

        if start <= end:
                return start <= x <= end
        else:
                return start <= x or x <= end

#wylaczenie komunikatow o bledach SSL (samopodpisane certyfikaty itp.)
urllib3.disable_warnings()

#
# argumenty
#
#
# ustawienie zmiennych - dostep do systemu
#

try:
    f = open("/etc/glog-appliance/var/variables.json", "rb")
except:
    print('[W] Unable to open file "/etc/glog-appliance/var/variables.json"!')

if f:
    variables = json.load(f)
    def_glog_host=variables["glog_host"]
    def_glog_port=variables["glog_port"]
    def_glog_proto=variables["glog_proto"]
    def_glog_token=variables["glog_token"]

parser = argparse.ArgumentParser()
parser.add_argument("-g","--glog_host", help="podaj nazwe hosta systemu Graylog", default=def_glog_host)
parser.add_argument("-p","--glog_port", help="podaj port systemu Graylog (domyslnie 9000)", default=def_glog_port)
parser.add_argument("-P","--glog_proto", help="podaj protokol dodstepu do systemu (domyslnie https)", default=def_glog_proto)
parser.add_argument("-t","--glog_token", help="podaj token API do systemu Graylog", default=def_glog_token)
parser.add_argument("-n","--new_var_name", required=True, help="nazwa zmiennej do utworzenia")
parser.add_argument("-d","--new_var_descr", required=True, help="opis tworzonej zmiennej")
parser.add_argument("-c","--new_var_content", required=True, help="wartosc zapisana w zmiennej")
args = parser.parse_args()

if args.glog_host == "":
        parser.print_help()
        quit()
if args.glog_port == "":
        parser.print_help()
        quit()
if args.glog_proto == "":
        parser.print_help()
        quit()
if args.glog_token == "":
        parser.print_help()
        quit()
if args.new_var_name == "":
        parser.print_help()
        quit()
if args.new_var_descr == "":
        parser.print_help()
        quit()
if args.new_var_content == "":
        parser.print_help()
        quit()

else:
    glog_host = args.glog_host
    glog_proto = args.glog_proto
    glog_port = args.glog_port
    glog_token = args.glog_token
    new_var_name = args.new_var_name
    new_var_descr = args.new_var_descr
    new_var_content = args.new_var_content


glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/sidecar/configuration_variables"

try:
    myResponse = requests.get(glogurl, verify=False, auth=(glog_token, 'token'))
except:
    print('[E] Unable to connect to ' + glogurl + '! Ending...')
    sys.exit(1)

var_id = ""

if(myResponse.ok):

    #
    # zaladowanie informacji o uzytkownikach Graylog
    #

    jResponse = json.loads(myResponse.content)
    glogurl = ""
    for key in jResponse:
        print(key['id'])

else:
    myResponse.raise_for_status()


#
# tworzenie zmiennej konfiguracji sidecar w Grayloog
#
#  odpowiedz myResponse inna niz 200 (ok) oznacza blad
#
glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/sidecar/configuration_variables"

headers = {
    'Content-Type': 'application/json',
    'X-Requested-By': 'cli',
}

data = {
    'name': new_var_name,
    'description': new_var_descr,
    'content': new_var_content,
}

print(data)

try:
    myResponse = requests.post(glogurl, headers=headers, json=data, verify=False, auth=(glog_token, 'token'))
except:
    print('[E] Unable to connect to ' + glogurl + '! Ending...')
    sys.exit(1)

if(myResponse.ok):

    #
    # zaladowanie informacji o dodanej zmiennej
    #

    jResponse = json.loads(myResponse.content)
    print(jResponse['id'])
    print(jResponse['name'])
    print(jResponse['description'])
    print(jResponse['content'])

else:
    myResponse.raise_for_status()
    #print(myResponse.headers)
