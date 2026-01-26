#!/usr/bin/env python3

#
# skrypt opracowany w ramach wdrozenia centralnego systemu syslog
# (c) 2026, Adam Dziadkiewicz
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

f = None

def_glog_host = ""
def_glog_port = ""
def_glog_proto = ""
def_glog_token = ""


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

else:
    glog_host = args.glog_host
    glog_proto = args.glog_proto
    glog_port = args.glog_port
    glog_token = args.glog_token

glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/sidecar/configurations"

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
    for key in jResponse['configurations']:
        print("Name: " + key['name'])
        print("ID: " + key['id'])
        confUrl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/sidecar/configurations/" + key['id']
        #print(confUrl)
        try:
            myResp = requests.get(confUrl, verify=False, auth=(glog_token, 'token'))
        except:
            print('[E] Unable to connect to ' + glogurl + '! Ending...')
            sys.exit(1)

        if(myResp.ok):
            jResp = json.loads(myResp.content)
            print("Color: " + jResp['color'])
            print("")
            print(jResp['template'])
        print("-------------------------")

else:
    myResponse.raise_for_status()


