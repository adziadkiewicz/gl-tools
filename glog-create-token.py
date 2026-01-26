#!/usr/bin/env python3

#
# skrypt opracowany w ramach wdrozenia centralnego systemu syslog
# (c) 2026, Adam Dziadkiewicz
#
# v1.0 t
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
    def_es_repo=variables["repo_name"]

parser = argparse.ArgumentParser()
parser.add_argument("-g","--glog_host", help="podaj nazwe hosta systemu Graylog", default=def_glog_host)
parser.add_argument("-p","--glog_port", help="podaj port systemu Graylog (domyslnie 9000)", default=def_glog_port)
parser.add_argument("-P","--glog_proto", help="podaj protokol dodstepu do systemu (domyslnie https)", default=def_glog_proto)
parser.add_argument("-t","--glog_token", help="podaj token API do systemu Graylog", default=def_glog_token)
parser.add_argument("-n","--new_token_name", required=True, help="nazwa tokenu do wygenerowania")
parser.add_argument("-u","--user_name", required=True, help="nazwa uzytkownika systemu Graylog")
parser.add_argument("-f","--file_name", help="nazwa pliku do zapisu tokenu")
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
if args.new_token_name == "":
        parser.print_help()
        quit()
if args.user_name == "":
        parser.print_help()
        quit()

else:
    glog_host = args.glog_host
    glog_proto = args.glog_proto
    glog_port = args.glog_port
    glog_token = args.glog_token
    new_token_name = args.new_token_name
    user_name = args.user_name
    file_name = args.file_name

#
# pobranie informacji dot. id uzytkownika Grayloog
#
#  odpowiedz myResponse inna niz 200 (ok) oznacza blad
#
glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/users/" + user_name

try:
        myResponse = requests.get(glogurl, verify=False, auth=(glog_token, 'token'))
except:
    print('[E] Unable to connect to ' + glogurl + '! Ending...')
    sys.exit(1)

user_id = ""

if(myResponse.ok):

    #
    # zaladowanie informacji o uzytkownikach Graylog
    #

    jResponse = json.loads(myResponse.content)
    user_id = jResponse['id']

else:
    myResponse.raise_for_status()

#
# pobranie informacji dot. id tokenu uzytkownika Grayloog
#
#  odpowiedz myResponse inna niz 200 (ok) oznacza blad
#
glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/users/" + user_id + "/tokens"

try:
        myResponse = requests.get(glogurl, verify=False, auth=(glog_token, 'token'))
except:
    print('[E] Unable to connect to ' + glogurl + '! Ending...')
    sys.exit(1)

if(myResponse.ok):

    #
    # zaladowanie informacji o tokenach uzytkownika Graylog
    #  -- usuniecie istniejacych tokenow o podanej nazwie

    jResponse = json.loads(myResponse.content)
    glogurl = ""
    for key in jResponse['tokens']:
        if key['name'] == new_token_name:

            glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/users/" + user_id + "/tokens/" + key['id'] + "/"
            #print(glogurl)

            headers = {
                'content-type': 'application/json',
                'Accept': 'application/json',
                'X-Requested-By': 'cli'
            }

            print('[I] Odnaleziono token uzytkownika "' + user_name + '", o nazwie "' + new_token_name + '" -- usuwam ... ')

            try:
                myResponse = requests.delete(glogurl, verify=False, headers=headers, auth=(glog_token, 'token'))
                #myResponse = requests.delete(glogurl, verify=False, auth=(glog_token, 'token'))
            except:
                print('[E] Unable to connect to ' + glogurl + '! Ending...')
                sys.exit(1)

            if myResponse.status_code == 204:
                print('.... token usuniety (id:' + key['id'] + ')')

    #
    #  -- dodanie nowego tokenu
    #

    glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/users/" + user_id + "/tokens/" + new_token_name

    headers = {
        'content-type': 'application/json',
        'Accept': 'application/json',
        'X-Requested-By': 'cli'
    }

    print('[I] Tworzenie tokenu uzytkownika "' + user_name + '", o nazwie "' + new_token_name + '" ... ')

    try:
        myResponse = requests.post(glogurl, verify=False, headers=headers, auth=(glog_token, 'token'))
    except:
        print('[E] Unable to connect to ' + glogurl + '! Ending...')
        sys.exit(1)

    if myResponse.status_code == 200:
        jResponse = json.loads(myResponse.content)
        print('.... token dodany prawidlowo!')
        print('ID:' + jResponse['id'])
        print('Nazwa: ' + jResponse['name'])
        print('Token: ' + jResponse['token'])

        if file_name != "":
            with open(file_name, 'w') as file:
                file.write(jResponse['token'] + "\n")

    #print(myResponse.status_code)

else:
    myResponse.raise_for_status()

