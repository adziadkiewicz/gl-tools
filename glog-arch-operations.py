#!/usr/bin/env python3

#
# skrypt umozliwiajacy przeglad kopii ES/OS w repozytorium dla systemu Graylog (min. v2.x), elasticsearch (min.2.4.x)
# (c) 2018-2026 Adam Dziadkiewicz
#

import requests
import json
import subprocess
import time
import logging
import certifi
import sys
import argparse
from datetime import timedelta
import urllib3
from datetime import datetime
#from opensearchpy import OpenSearch
from elasticsearch import Elasticsearch

#wylaczenie komunikatow o bledach SSL (samopodpisane certyfikaty itp.)
urllib3.disable_warnings()


#
# funkcja spawdzajaca poprawnosc stringu z data
#
def try_parseDate(s, fmts):
        for fmt in fmts:
                try:
                        return datetime.strptime(s, fmt)
                except:
                        continue

                return None


#
# ustawienie zmiennych - dostep do systemu
#
#   zmienne dot. opensearch
#
try:
    f = open("/etc/glog-appliance/var/variables.json", "rb")
except:
    print('[E] Unable to open file "/etc/glog-appliance/var/variables.json"! Ending...')
    sys.exit(1)


if f:
    variables = json.load(f)
    es_repo = variables["repo_name"]
    es_host = variables["es_host"]
    es_proto = variables["es_proto"]
    es_port = variables["es_port"]
    es_snap_create_timeout = variables["es_snap_create_timeout"]
else:
    es_host = "localhost"
    es_proto = "http"
    es_port = "9200"

log_filename = "/var/log/glog-arch-rotation.log"
logging.basicConfig(filename=log_filename,level=logging.DEBUG,filemode='a',format='%(asctime)s %(message)s')

parser = argparse.ArgumentParser()
parser.add_argument("-o","--operation", help="rodzaj operacji na danych: list|remove", default="list")
parser.add_argument("-b","--date_begin", help="data poczatkowa archiwum zakresu oparacji", default="1970-01-01")
parser.add_argument("-e","--date_end", help="data koncowa archiwum zakresu operacji", default="1970-01-01")
parser.add_argument("-r","--es_repo", help="repozytorium backupow Elasticsearch (domyslnie \'glog_arch\')", default=es_repo)
args = parser.parse_args()

if args.es_repo == "":
        parser.print_help()
        quit()

else:
    es_repo = args.es_repo
    es_snap_operation_timeout = 1000
    #
    #   inicjalizacja polaczenia z ES/OS
    #
    #es = OpenSearch(es_proto + "://" + es_host + ":" + es_port)
    es = Elasticsearch(es_proto + "://" + es_host + ":" + es_port)

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
lIndicesInSnaps_UUIDs = {}
lIndicesInSnaps_Versions = {}

if(myResponse.ok):

    #
    # zaladowanie informacji o snapshotach indeksow do listy lSnaps
    #
    jSnaps = json.loads(myResponse.content)
    for key in jSnaps['snapshots']:
        lSnap = key['snapshot']
        lSnaps += [key['snapshot']]
        lIndicesInSnaps[key['snapshot']] = [key['indices'][0]]
        lIndicesInSnaps_UUIDs[key['snapshot']] = key['uuid']
        lIndicesInSnaps_Versions[key['snapshot']] = key['version']
        dtBegin=try_parseDate(lSnap[0:13],['%Y%m%d%H%M%S','%Y%m%d'])
        if (dtBegin is None):
            dtBegin=try_parseDate(lSnap[0:8],['%Y%m%d%H%M%S','%Y%m%d'])
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
        #print(key['snapshot'] + " " + key['uuid'] + " " + key['version'] + " " + key['indices'][0] + " " + strDTBegin + " " + strDTEnd)

else:
    myResponse.raise_for_status()

i=0
j=0
lIndicesToRecover = []
lIndicesToOverwrite = []
lSelectedSnaps = []

for key in lSnaps:
    if (date_start.date() <= lIndicesInSnaps_BeginDates[key].date() <= date_end.date()) \
        and (date_start.date() <= lIndicesInSnaps_EndDates[key].date() <= date_end.date()):
            lSelectedSnaps += [key]
            i += 1

print("Przetwarzam " + str(i) + " wpisow...")
logging.info("Przetwarzam " + str(i) + " wpisow...")

if args.operation == "list":
    for key in lSelectedSnaps:
        #print(key)
        print(key + " " + lIndicesInSnaps_UUIDs[key] + " " + lIndicesInSnaps_Versions[key] + " " + lIndicesInSnaps[key][0] + " " + lIndicesInSnaps_BeginDates[key].date().strftime('%Y-%m-%d') + " " + lIndicesInSnaps_EndDates[key].date().strftime('%Y-%m-%d'))

if args.operation == "remove":
    for key in lSelectedSnaps:
        #if key == "19700101000000-19700101000000-ad-audit_2":
        print("Usuwam snapshot " + key + "...")
        logging.info("Usuwam snapshot " + key + "...")
        es.snapshot.delete(repository=es_repo,snapshot=key)
