#!/bin/bash

#
# Screensaver Stop Event
# This script is called when the RCade screensaver stops
#

# BASE URL for RESTful calls to Pixelcade
PIXELCADEBASEURL="http://127.0.0.1:8080/"

# Stop attract mode
PIXELCADEURL="attract/stop"
curl -s "$PIXELCADEBASEURL$PIXELCADEURL" >> /dev/null 2>/dev/null &
