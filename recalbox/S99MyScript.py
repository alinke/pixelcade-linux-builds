#!/bin/bash

case "$1" in
   start)
         cd /etc/init.d/pixelcade && ./pixelweb -p /recalbox/share/pixelcade-art/ -port 7070 -image "system/recalbox.png" -startup &
         ;;
   stop)
         #Add your stop code here
         ;;
   restart|reload)
         #Add your restart / reload code here
         ;;
   *)
esac

exit $?
