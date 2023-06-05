#!/bin/bash

./etc/glog-appliance/var/variables.bash

stor_es_warnLevel=75
stor_es_arch_warnLevel=85
stor_gl_warnLevel=75
stor_gl_journal_warnLevel=75

stor_es_errLevel=85
stor_es_arch_errLevel=92
stor_gl_errLevel=85
stor_gl_journal_errLevel=85

usage_es=`df -P -k $stor_es | tail -1 | awk '{ print $5 }' | sed 's/%//'`
usage_es_arch=`df -P -k $stor_es_arch | tail -1 | awk '{ print $5 }' | sed 's/%//'`
usage_gl=`df -P -k $stor_gl | tail -1 | awk '{ print $5 }' | sed 's/%//'`
usage_gl_journal=`df -P -k $stor_gl_journal | tail -1 | awk '{ print $5 }' | sed 's/%//'`

stor_es_warn=false
stor_es_arch_warn=false
stor_gl_warn=false
stor_gl_journal_warn=false

[[ usage_es -ge stor_es_warnLevel ]] && stor_es_warn=true
[[ usage_es_arch -ge stor_es_arch_warnLevel ]] && stor_es_arch_warn=true
[[ usage_gl -ge  stor_gl_warnLevel ]] && stor_gl_warn=true
[[ usage_gl_journal -ge stor_gl_journal_warnLevel ]] && stor_gl_journal_warn=true

#echo $stor_es_warn
#echo $stor_es_arch_warn
#echo $stor_gl_warn
#echo $stor_gl_journal_warn

stor_es_err=false
stor_es_arch_err=false
stor_gl_err=false
stor_gl_journal_err=false

[[ usage_es -ge stor_es_errLevel ]] && stor_es_err=true
[[ usage_es_arch -ge stor_es_arch_errLevel ]] && stor_es_arch_err=true
[[ usage_gl -ge  stor_gl_errLevel ]] && stor_gl_err=true
[[ usage_gl_journal -ge stor_gl_journal_errLevel ]] && stor_gl_journal_err=true


stor_es_mp_err=false
stor_es_arch_mp_err=false
stor_gl_mp_err=false
stor_gl_journal_mp_err=false

#Check 
#mountpoint -q /mnt/glog-arch || echo "ERROR NOT MOUNTED"

mountpoint -q $stor_es_mountpoint || stor_es_mp_err=true
mountpoint -q $stor_es_arch_mountpoint || stor_es_arch_mp_err=true
mountpoint -q $stor_gl_mountpoint || stor_gl_mp_err=true
mountpoint -q $stor_gl_journal_mountpoint || stor_gl_journal_mp_err=true


date=`date +%Y-%m-%d\ %H:%M:%S`

echo "glsw_head=glog-storage-watchdog glsw_host=$HOSTNAME glsw_tm='$date' glsw_stor_type=stor_es glsw_stor=$stor_es glsw_usage=$usage_es glsw_stor_warnLevel=$stor_es_warnLevel glsw_stor_warn=$stor_es_warn glsw_stor_errLevel=$stor_es_errLevel glsw_stor_err=$stor_es_err glsw_stor_mp=$stor_es_mountpoint glsw_stor_mp_err=$stor_es_mp_err"

echo "glsw_head=glog-storage-watchdog glsw_host=$HOSTNAME glsw_tm='$date' glsw_stor_type=stor_es_arch glsw_stor=$stor_es_arch glsw_usage=$usage_es_arch glsw_stor_warnLevel=$stor_es_arch_warnLevel glsw_stor_warn=$stor_es_arch_warn glsw_stor_errLevel=$stor_es_arch_errLevel glsw_stor_err=$stor_es_arch_err glsw_stor_mp=$stor_es_arch_mountpoint glsw_stor_mp_err=$stor_es_arch_mp_err"

echo "glsw_head=glog-storage-watchdog glsw_host=$HOSTNAME glsw_tm='$date' glsw_stor_type=stor_gl glsw_stor=$stor_gl glsw_usage=$usage_gl glsw_stor_warnLevel=$stor_gl_warnLevel glsw_stor_warn=$stor_gl_warn glsw_stor_errLevel=$stor_gl_errLevel glsw_stor_err=$stor_gl_err glsw_stor_mp=$stor_gl_mountpoint glsw_stor_mp_err=$stor_gl_mp_err"

echo "glsw_head=glog-storage-watchdog glsw_host=$HOSTNAME glsw_tm='$date' glsw_stor_type=stor_gl_journal glsw_stor=$stor_gl_journal glsw_usage=$usage_gl_journal glsw_stor_warnLevel=$stor_gl_journal_warnLevel glsw_stor_warn=$stor_gl_journal_warn glsw_stor_errLevel=$stor_gl_journal_errLevel glsw_stor_err=$stor_gl_journal_err glsw_stor_mp=$stor_gl_journal_mountpoint glsw_stor_mp_err=$stor_gl_journal_mp_err"
