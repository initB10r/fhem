#!/bin/sh

oldPwd=`pwd`
#echo $oldPwd
cd /opt/fhem-tablet-ui
git pull
git fetch 
cp /opt/fhem-tablet-ui/www/* /opt/fhem/www/ -R
cd $oldPwd
