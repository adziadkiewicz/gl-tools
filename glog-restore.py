#!/usr/bin/env python3

#
# skrypt opracowany w ramach wdrozenia centralnego systemu syslog
# (c) 2017, AD, Salutaris Sp. z o.o.
#
# v2.1
# - dodanie obslugi bledow
# - dodanie parametrow glog_proto oraz es_proto
#
# 	v2.0
#   	- aktualizacja do python3

import requests
import json
import subprocess
import time
import logging
import sys
import getopt
import argparse
from datetime import datetime
from datetime import timedelta
from elasticsearch import Elasticsearch

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
    def_glog_host=variables["glog_host"]
    def_glog_port=variables["glog_port"]
    def_glog_proto=variables["glog_proto"]
    def_glog_token=variables["glog_token"]
    def_es_repo=variables["repo_name"]

parser = argparse.ArgumentParser()
parser.add_argument("-g","--glog_host", required=True, help="podaj nazwe hosta systemu Graylog", default=def_glog_host)
parser.add_argument("-p","--glog_port", help="podaj port systemu Graylog (domyslnie 9000)", default=def_glog_port)
parser.add_argument("-P","--glog_proto", help="podaj protokol dodstepu do systemu (domyslnie https)", default=def_glog_proto)
parser.add_argument("-t","--glog_token", required=True, help="podaj token API do systemu Graylog", default=def_glog_token)
parser.add_argument("-b","--date_begin", required=True, help="data poczatkowa archiwum zakresu do odtworzenia", default="")
parser.add_argument("-e","--date_end", required=True, help="data koncowa archiwum zakresu do odtworzenia", default="")
parser.add_argument("-r","--es_repo", help="repozytorium backupow Elasticsearch (domyslnie \'glog_arch\')", default=def_es_repo)
args = parser.parse_args()

if args.glog_host == "":
        parser.print_help()
        quit()
if args.glog_token == "":
        parser.print_help()
        quit()
if args.date_begin == "":
        parser.print_help()
        quit()
if args.date_end == "":
        parser.print_help()
        quit()

else:
        glog_host = args.glog_host
        glog_proto = args.glog_proto
        glog_port = args.glog_port
        glog_token = args.glog_token
        es_host = "localhost"
        es_proto = "http"
        es_port = "9200"
        es_repo = args.es_repo
        es_snap_restore_timeout = 1000
        es = Elasticsearch()
        date_start = try_parseDate(args.date_begin,['%Y%m%d%H%M%S','%Y-%m-%d'])
        if (date_start is None):
                print("Niepoprawna data rozpoczecia!")
                parser.print_help()
                quit()

        date_end = try_parseDate(args.date_end, ['%Y%m%d%H%M%S','%Y-%m-%d'])
        if (date_end is None):
                print("Niepoprawna data konca!")
                parser.print_help()
                quit()

        if date_start > date_end:
                print("Data rozpoczecia jest pozniejsza niz data rozpoczecia!")
                parser.print_help()
                quit()

#
# pobranie informacji dot. indeksow elasticsearch Graylog
#  zmienna lIndexNames zawiera liste indeksow w domyslnym zestawie
#  odpowiedz myResponse inna niz 200 (ok) oznacza blad
#
glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/system/indices/ranges"

try:
	myResponse = requests.get(glogurl, verify=False, auth=(glog_token, 'token'))
except:
        print('[E] Unable to connect to ' + glogurl + '! Ending...')
        sys.exit(1)

lIndexNames = []

if(myResponse.ok):

        #
        # zaladowanie informacji o uzywanych indeksach przez Graylog
        #

        jIndices = json.loads(myResponse.content)
        for key in jIndices['ranges']:
                lIndexNames += [key['index_name']]

else:
        myResponse.raise_for_status()


#
# pobranie informacji dot. istniejacych w repozytorium snapshot-ow (elasticsearch)
#  zmienna lSnaps zawiera liste indeksow zarchiwizowanych jako snapshoty w repozytorium
#  odpowiedz myResponse inna niz 200 (ok) oznacza blad
#

url = es_proto + "://" + es_host + ":" + es_port + "/_snapshot/" + es_repo + "/_all"

try:
	myResponse = requests.get(url, verify=True)
except:
        print('[E] Unable to connect to ' + url + '! Ending...')
        sys.exit(1)

lSnaps = []
lIndicesInSnaps = {}
lIndicesInSnaps_BeginDates = {}
lIndicesInSnaps_EndDates = {}


if(myResponse.ok):

        #
        # zaladowanie informacji o snapshotach indeksow do listy lSnaps
        #
        jSnaps = json.loads(myResponse.content)
        for key in jSnaps['snapshots']:
                lSnap = key['snapshot']
                lSnaps += [key['snapshot']]
                lIndicesInSnaps[key['snapshot']] = [key['indices'][0]]
                dtBegin=try_parseDate(lSnap[0:13],['%Y%m%d%H%M%S','%Y%m%d'])
                if (dtBegin is None): dtBegin=try_parseDate(lSnap[0:8],['%Y%m%d%H%M%S','%Y%m%d'])
                dtEnd=try_parseDate(lSnap[15:28],['%Y%m%d%H%M%S','%Y%m%d'])
                if (dtBegin is None) and (dtEnd is None):
                        lIndicesInSnaps_BeginDates[key['snapshot']] = datetime.strptime("1970-01-01","%Y-%m-%d")
                        lIndicesInSnaps_EndDates[key['snapshot']] = datetime.strptime("1970-01-01","%Y-%m-%d")
                if (dtBegin is not None) and (dtEnd is None):
                        lIndicesInSnaps_BeginDates[key['snapshot']] = dtBegin
                        lIndicesInSnaps_EndDates[key['snapshot']] = dtBegin + timedelta(days=1)
                if (dtBegin is not None) and (dtEnd is not None):
                        lIndicesInSnaps_BeginDates[key['snapshot']] = dtBegin
                        lIndicesInSnaps_EndDates[key['snapshot']] = dtEnd

else:
        myResponse.raise_for_status()


i=0
j=0
lIndicesToRecover = []
lIndicesToOverwrite = []
lSnapsToRecover = []

for key in lSnaps:
        if (date_start.date() <= lIndicesInSnaps_BeginDates[key].date() <= date_end.date()) \
                and (date_start.date() <= lIndicesInSnaps_EndDates[key].date() <= date_end.date()):
                lIndicesToRecover += lIndicesInSnaps[key]
                lSnapsToRecover += [key]
                if lIndicesInSnaps[key][0] in lIndexNames:
                        lIndicesToOverwrite += lIndicesInSnaps[key]
                        j += 1
                i += 1

print(lSnapsToRecover)

if i > 20:
        if not query_yes_no("!UWAGA! Chcesz odtworzyc wiecej niz 20 indeksow. To moze byc dlugotrwaly i obciazajacy system proces. Czy na pewno chcesz kontynuowac ?","no"):
                quit()

if i == 0:
        print("W archiwum '" + es_repo + "' nie ma danych spelniajacych kryteria... ")
else:
        print("")
        print("Zamierzasz odtworzyc nastepujace indeksy:")
        print(lIndicesToRecover)
        print("")
        print("ILOSC: " + str(i))
        print("")
        if j > 0:
                print("")
                print("!UWAGA! Nastepujace indeksy musza zostac usuniete przed operacja:")
                print(" Usun indeksy i powtorz operacje ")
                print(lIndicesToOverwrite)
                print("")
                print("ILOSC: " + str(j))
                print("")
                quit()

        if query_yes_no("Czy NA PEWNO kontynuowac ?"):
                for snap in lSnapsToRecover:
                        print(" odtwarzam '" + snap + "' z repozytorium '" + es_repo + "' ... ")
                        try:
                                es.snapshot.restore(repository=es_repo,snapshot=snap,body="{\"ignore_unavailable\":\"true\",\"include_global_state\":false}",request_timeout=es_snap_restore_timeout,wait_for_completion=True)

                        except:
                                print("[E] Ups... Cos poszlo nie tak - blad elasticsearch podczas odtworzenia indeksu '" + snap + "' z repozytorium '" + es_repo + "'")
