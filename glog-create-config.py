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




parser = argparse.ArgumentParser()
parser.add_argument("-gh","--glog_host", required=True, help="podaj nazwe lub ip hosta Graylog")
parser.add_argument("-gp","--glog_port", required=True, help="podaj port systemu Graylog (domyslnie 9000)", default=9000)
parser.add_argument("-gP","--glog_proto", required=True, help="podaj protokol dodstepu do systemu (domyslnie https)", default="https")
parser.add_argument("-gt","--glog_token", required=True, help="podaj admin token API do systemu Graylog")
parser.add_argument("-eh","--es_host", required=True, help="podaj nazwe lub ip hosta Elasticsearch/Opensearch")
parser.add_argument("-ep","--es_port", required=True, help="podaj port systemu Elasticsearch/Opensearch (domyslnie 9200)", default=9200)
parser.add_argument("-eP","--es_proto", required=True, help="podaj protokol dostepu do systemu Elasticsearch/Opensearch (domyslnie http)", default="http")
parser.add_argument("-er","--es_repo", required=True, help="podaj nazwe repozytorium Elasticsearch/Opensearch (domyslnie glog-arch)", default="glog-arch")
parser.add_argument("-af","--glog_arch_log", required=True, help="poodaj sciezke logu archiwizacji Graylog")
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
if args.es_host == "":
        parser.print_help()
        quit()
if args.es_port == "":
        parser.print_help()
        quit()
if args.es_proto == "":
        parser.print_help()
        quit()
if args.es_repo == "":
        parser.print_help()
        quit()
if args.glog_arch_log == "":
        parser.print_help()
        quit()

else:
    glog_host = args.glog_host
    glog_proto = args.glog_proto
    glog_port = args.glog_port
    glog_token = args.glog_token
    es_host = args.es_host
    es_port = args.es_port
    es_proto = args.es_proto
    es_repo = args.es_repo
    glog_arch_log = args.glog_arch_log



try:
    f = open("/etc/glog-appliance/var/variables.json", "rw")
except:
    print('[E] Unable to open file "/etc/glog-appliance/var/variables.json"!')
    quit()
    
if f:
    variables = {}
    variables["repo_name"] = es_repo
    variables["es_host"] = es_host
    variables["es_proto"] = es_proto
    variables["es_port"] = es_port
    variables["es_snap_create_timeout"] = 1000
    variables["glog_host"] = glog_host
    variables["glog_proto"] = glog_proto
    variables["glog_port"] = glog_port
    variables["glog_token"] = glog_token
    variables["log_filename"] = glog_arch_log
    json.dump(variables, f)


