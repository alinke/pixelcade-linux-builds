#!/bin/bash
# Code here will be executed on every boot and shutdown.

# Check if security is enabled and store that setting to a variable.
#securityenabled="$(/usr/bin/batocera-settings-get system.security.enabled)"

case "$1" in
    start)
        # Code in here will only be executed on boot.
        cd /userdata/system/pixelcade && ./pixelweb -image "system/batocera.png" -fuzzy -startup &
        ;;
    stop)
        # Code in here will only be executed on shutdown.
        # TO DO add Pixelcade LCD shutdown command here later

        ;;
    restart|reload)
        # Code in here will executed (when?).

        ;;
    *)
        # Code in here will be executed in all other conditions.
        #echo "Usage: $0 {start|stop|restart}"
        ;;
esac

exit $?
