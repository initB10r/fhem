#!/bin/sh

oldPwd=`pwd`
echo $oldPwd
cd /opt/FHEM-HM485
git pull
git fetch 
cp /opt/FHEM-HM485/FHEM/* /opt/fhem/FHEM/ -R
cd $oldPwd
