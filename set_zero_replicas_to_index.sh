#!/bin/bash
curl -H 'Content-Type: application/json' -XPUT "http://localhost:9200/$1/_settings?pretty" -d '{
    "index" : {
        "number_of_replicas" : 0
    }
}'
