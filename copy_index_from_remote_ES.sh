#!/bin/bash

curl -H 'Content-Type: application/json' -X POST 127.0.0.1:9200/_reindex?pretty -d "{
  \"source\": {
    \"remote\": {
      \"host\": \"http://$1:9200\"
    },
    \"index\": \"$2\"
  },
  \"dest\": {
    \"index\": \"$3\"
  }
}"
