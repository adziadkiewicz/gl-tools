#!/bin/bash
curl -s -XDELETE "http://localhost:9200/$1?pretty"
