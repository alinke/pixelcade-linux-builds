#!/bin/bash

#
# Screensaver Start Event
# This script is called when the RCade screensaver starts
#

# BASE URL for RESTful calls to Pixelcade
PIXELCADEBASEURL="http://127.0.0.1:8080/"

# Start attract mode with no interrupt (won't stop on button press)
PIXELCADEURL="attract?nointerrupt"
curl -s "$PIXELCADEBASEURL$PIXELCADEURL" >> /dev/null 2>/dev/null &
