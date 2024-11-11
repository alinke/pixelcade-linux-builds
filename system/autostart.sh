#!/bin/bash
# startup script for a dedicated Pi for Pixelcade that is not running RetroPie, systemd calls this via /etc/systemd/system/pixelcade.service
PIXELHOME=$HOME/pixelcade
cd $PIXELHOME && ./pixelweb -image "system/pixelcade.png" -startup &
