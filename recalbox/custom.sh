#!/bin/bash

case "$1" in
   start)
         cd /recalbox/share/pixelcade && ./pixelweb -image "system/recalbox.png" -startup &
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
