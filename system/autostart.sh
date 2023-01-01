#!/bin/bash
# startup script for a dedicated Pi for Pixelcade, systemd calls this via /etc/systemd/system/pixelcade.service
PIXELHOME=$HOME/pixelcade
cd $PIXELHOME && ./pixelweb &
