#!/usr/bin/env python3

#
# skrypt archiwizacyjny dla systemu Graylog (min. v2.x), elasticsearch (min.2.4.x)
# (c) 2018-2023 AD, Salutaris Sp. z o.o.
#
# v 4.0
# - dodanie obsługi OpenSearch
#
#
# v 3.1
# - dodanie mechanizmu przegladu zestawu indeksow i wylaczenie deflektorow (indeksow R/W)
#
# v 3.0
# - poprawka 2023 - elasticsearch 7.x
# - wylaczenie komunikatow o bledach SSL (samopodpisane certyfikaty itp.)
# 
# v 2.4
# - poprawka bledu inicjalizacji es = Elasticsearch(es_proto + "://" + es_host + ":" + es_port)
#
# v.2.3
# - wlaczenie obslugi bledow 
# - dodanie parametru es_proto oraz glog_proto
#
# 	HISTORIA:
#	v2.2
#       aktualizacja do python3, elasticsearch 6.x
# 
#
#	UWAGA: nalezy wykonac dos2unix przed uzyciem pliku !
#	UWAGA2: dziala z wersja modulu elasticsearch==7.14 (nie dziala z 8.1.x!)
#

import requests
import json
import subprocess
import time
import logging
import certifi
import sys
import urllib3
from datetime import datetime
from elasticsearch import Elasticsearch

#
# ustawienie zmiennych - dostep do systemu
#
#   zmienne dot. elasticsearch
#
repo_name = "glog-arch"
es_host = "localhost"
es_proto = "http"
es_port = "9200"
es_snap_create_timeout = 1000
#es = Elasticsearch()
es = Elasticsearch(es_proto + "://" + es_host + ":" + es_port)

#
#   zmienne dot. graylog
#       token nalezy wygenerowac w GUI Graylog
#
glog_host = "172.16.0.200"
glog_proto = "https"
glog_port = "9000"
glog_token = "1t634853h5c7ob55rlmk8to3ffdpq2dvq03gunb1cuvba2kabiae"

#
#   zmienne ogolne
#
log_filename = "/var/log/glog-arch.log"

#wylaczenie komunikatow o bledach SSL (samopodpisane certyfikaty itp.)
urllib3.disable_warnings()

#
# ustawienie logowania do pliku
#
logging.basicConfig(filename=log_filename,level=logging.DEBUG,filemode='a',format='%(asctime)s %(message)s')


#
# pobranie indeksow elasticsearch (filtr: tylko otwarte, bez indeksow RW)
#


#
#       (1) Sprawdzenie zestawow indeksow i zapis do listy lIndexSets (z Graylog)
#

glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/system/indices/index_sets"

try:
	myResponse = requests.get(glogurl, verify=False, auth=(glog_token, 'token'))
except:
	print('[E] Unable to connect to ' + glogurl + '! Ending...')
	sys.exit(1)

lIndexSets = []
lIndexSetsTitle = {}
lIndexSetsPrefix = {}
lIndexSetsDeflectors = {}

if(myResponse.ok):

        #
        # zaladowanie informacji z API Graylog (default index set)
        #
        #print(myResponse.content)
        jIndexSets = json.loads(myResponse.content)
        #print(jIndexSets)
        for key in jIndexSets['index_sets']:
            #print(key)
            lIndexSets += [key['id']]
            lIndexSetsTitle[key['id']] = key['title']
            lIndexSetsPrefix[key['id']] = key['index_prefix']

            try:
                glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/system/deflector/" + key['id']
                myResponse = requests.get(glogurl, verify=False, auth=(glog_token, 'token'))
            except:
                print('[E] Unable to connect to ' + glogurl + '! Ending...')
                sys.exit(1)
            if(myResponse.ok):  
                jDeflector = json.loads(myResponse.content)       
                lIndexSetsDeflectors[key['id']] = jDeflector['current_target']

#
#       (2) Utworzenie listy pozostalych indeksow wylaczajac RW (deflector) (z Graylog)
#               wraz z informacja o zakresie czasowym logow zawartych w indeksie
#

glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/system/indices/ranges"

try:
	myResponse = requests.get(glogurl, verify=False, auth=(glog_token, 'token'))
except:
	print('[E] Unable to connect to ' + glogurl + '! Ending...')
	sys.exit(1)

lIndices = []
lIndicesBeginDate = {}
lIndicesEndDate = {}

if(myResponse.ok):

        #
        # zaladowanie informacji indeksach do listy lIndices oraz
        #  - daty i godziny poczatku logow w indeksie do slownika lIndicesBeginDate
        #  - daty i godziny konca logow w indeksie do slownika lIndicesEndDate
        #       w formacie lIndices[Begin|End]Date['nazwa_indeksu'] = [BEGIN|END]Date
        #
        jIndices = json.loads(myResponse.content)
        for key in jIndices['ranges']:
                #print(key)
                skip = False
                for k in lIndexSets:
                    if key['index_name'] == lIndexSetsDeflectors[k]:
                        print("Indeks \'" +  key['index_name'] + "\' jest w trybie zapis/odczyt. Pomijam.")
                        logging.info("Indeks \'" +  key['index_name'] + "\' jest w trybie zapis/odczyt. Pomijam.")
                        skip = True
                if not skip:
                    lIndices += [key['index_name']]
                    lIndicesBeginDate[key['index_name']] = key['begin']
                    lIndicesEndDate[key['index_name']] = key['end']
                    print("Dodaje do listy indeksow \'" +  key['index_name'] + "\'")
                    logging.info("Dodaje do listy indeksow \'" +  key['index_name'] + "\'")

#
#       (3) pobranie informacji dot. istniejacych w repozytorium snapshotow (elasticsearch)
#               zmienna lSnaps zawiera liste indeksow zarchiwizowanych jako snapshoty w repozytorium
#               odpowiedz myResponse inna niz 200 (ok) oznacza blad
#

url = es_proto + "://" + es_host + ":" + es_port + "/_snapshot/" + repo_name + "/_all"

try:
	myResponse = requests.get(url, verify=True)
except:
        print('[E] Unable to connect to ' + url + '! Ending...')
        sys.exit(1)

lSnaps = []

if(myResponse.ok):

        #
        # zaladowanie informacji o snapshotach indeksow do listy lSnaps
        #
        jSnaps = json.loads(myResponse.content)
        for key in jSnaps['snapshots']:
                lSnaps += [key['indices'][0]]

else:
    myResponse.raise_for_status()

#
#       (4) porownanie indeksow istniejacych w domyslnym zestawie (Graylog)
#               z lista zarchiwizowanych indeksow zapisana w zmiennej lSnaps
#               odpowiedz myResponse inna niz 200 (ok) oznacza blad
#


glogurl = glog_proto + "://" + glog_host + ":" + glog_port + "/api/system/indices/ranges"

try:
	myResponse = requests.get(glogurl, verify=False, auth=(glog_token, 'token'))
except:
        print('[E] Unable to connect to ' + glogurl + '! Ending...')
        sys.exit(1)

if(myResponse.ok):

        #
        # dla kazdego otwartego indeksu:
        #  (1) sprawdz czy juz istnieje jego snap w repozytorium
        #   (a) jesli tak to pomin
        #   (b) jesli nie to utworz snapshot o nazwie {DATAOD}-{DATADO}-{nazwa_indeksu}
        #


        for esIndex in lIndices:
                if esIndex in lSnaps:
                        print("Indeks \'" + esIndex + "\' juz jest zarchiwizowany w repozytorium \'" + repo_name + "\'. Pomijam.")
                        logging.info("Indeks \'" + esIndex + "\' juz jest zarchiwizowany w repozytorium \'" + repo_name + "\'. Pomijam.")
                else:
                        sDateBegin = lIndicesBeginDate[esIndex]
                        sDateBegin = sDateBegin.replace("T", " ")
                        sDateBegin = sDateBegin.replace("Z", "")
                        sDateEnd = lIndicesEndDate[esIndex]
                        sDateEnd = sDateEnd.replace("T", " ")
                        sDateEnd = sDateEnd.replace("Z", "")
                        dtBegin = datetime.strptime(sDateBegin,'%Y-%m-%d %H:%M:%S.%f')
                        dtEnd = datetime.strptime(sDateEnd,'%Y-%m-%d %H:%M:%S.%f')
                        strDate = dtBegin.strftime('%Y%m%d%H%M%S') + "-" + dtEnd.strftime('%Y%m%d%H%M%S')
                        print("Tworze snapshot indeksu '" + esIndex + "' o nazwie '" + strDate + "-" + esIndex + "' w repozytorium '" + repo_name + "' ... ")
                        logging.info("Tworze snapshot indeksu '" + esIndex + "' o nazwie '" + strDate + "-" + esIndex + "' w repozytorium '" + repo_name + "' ... ")
                        try:
                                sBodyDebug="{\"indices\":\"" + esIndex + "\", \"include_global_state\": false}"
                                es.snapshot.create(repository=repo_name,snapshot=strDate + "-" + esIndex,body=sBodyDebug,request_timeout=es_snap_create_timeout,wait_for_completion=True)
                        except Exception as e:
                                print(sBodyDebug)
                                print(" -- Ups... Cos poszlo nie tak - blad es podczas tworzenia snapshot '" + strDate + "-" + esIndex + "' w repozytorium '" + repo_name + "'. Komunikat ES:'" + str(e) + "'")
                                logging.error(" -- Ups... Cos poszlo nie tak - blad es podczas tworzenia snapshot '" + strDate + "-" + esIndex + "' w repozytorium '" + repo_name + "'. Komunikat ES:'" + str(e) + "'")

else:
        myResponse.raise_for_status()
