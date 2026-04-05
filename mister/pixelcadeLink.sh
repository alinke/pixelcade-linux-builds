#!/bin/sh
touch /tmp/CURRENTPATH
touch /tmp/CORENAME
touch /tmp/FULLPATH

# Debounce delay in seconds — how long to wait after scrolling stops before sending to Pixelcade.
# Recommended values: 0.2 (fast), 0.3 (default), 0.5 (relaxed), 1.0 (slow/original)
# Override by writing a number to /media/fat/pixelcade/debounce.txt
DEBOUNCE=$(cat /media/fat/pixelcade/debounce.txt 2>/dev/null | tr -d '[:space:]')
if [ -z "${DEBOUNCE}" ]; then
  DEBOUNCE=0.3
fi

lastCall=""  # moved outside the function so it persists between calls
debounceJob=""  # tracks the current debounce background job

function urlencode {
#These are enabled by my changes to MiSTer
name=`cat /tmp/CURRENTPATH`
fullPath=`cat /tmp/FULLPATH`
#This is provided by MiSTer by default
system=`cat /tmp/CORENAME`

HOST=${1}
#From SO or a gist...
function encode {
 local string="${1}"
 local strlen=${#string}
 local encoded=""
#  pos c o
  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:${pos}:1}
     case "${c}" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'${c}"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"
}

if [[ $fullPath == "_"*  ]] && [ "${fullPath}" != "_Arcade"  ]; then
  core=`cat /tmp/CURRENTPATH`
  name="${core}"
  system="console"
  echo "Synthesized Console: ${system}/${name}"
fi
#If we are in here in Arcade, we should request the 'mame name' and not what is on the OSD
if [[ $fullPath == "_Arcade"*  ]]; then
  core=`cat /tmp/CURRENTPATH`
# this looks for an underscore in the game name which occurs when we are in a sub-folder
  if [ "${core:0:1}" == "_" ]; then
      core="${core:1}"
      echo $core
  fi
  name="${core}.zip"
  system="mame"
  echo "Synthesized Arcade: ${system}/${name}"
fi
#for the top level in Mister menu, fullpath will always be blank so if that is the case, map to console
if [[ $fullPath == ""  ]]; then
  core=`cat /tmp/CURRENTPATH`
  name="${core}"
  system="console"
fi
#If the file does not have an extension for the rom, add ".zip" to the call
ext="${current##*.}"
base="${current##*/}"
echo "We have: ${base}.${ext}"

#urlencode everything
encn=`encode "${name}"`
encn=${encn%.*} #strip out the extension BUT this will break any games with another . in the name
encs=`encode "${system}"`
enct=`encode "${base}"`

if [ "${lastCall}" != "${enct}"  ] && [ "${enct}" != ".."  ] ; then
 curl "http://${HOST}:8080/arcade/stream/${encs}/${encn}" &  # & makes it asynchronous so the script doesn't wait for a response
 lastCall="${enct}"
 else
  echo "REJECTING: Last call was the same as ${enct} or we have a .."
fi
}

lastPath="@MARU"
pixelcadeIP=`cat /media/fat/pixelcade/ip.txt 2>/dev/null`
  if [ "${1}" == "" ] && [ "${pixelcadeIP}" == "" ]; then
    echo "version: 1.3"
    echo "Usage: pixecadeLink <pixelcade_ip_address>"
    echo "Shows the currently selected title on a Pixelcade, or a generic marquee if unavailable/no match."
    exit
  fi
  if [ "${1}" != "" ] && [ "${pixelcadeIP}" == "" ]; then
    pixelcadeIP=${1}
  fi
echo ":::::::::::::::::::"
echo "::               ::"
echo ":: PixelcadeLink ::"
echo ":: v1.6         ::"
echo "::               ::"
echo ":::::::::::::::::::"
echo "/IP: ${pixelcadeIP}"
echo "Ready."
echo
inotifywait -qm  --timefmt '%Y-%m-%dT%H:%M:%S' --event close_write --format '%T %w %f %e' /tmp/CURRENTPATH | while read datetime dir filename event; do
  if [[ ${dir} != _* ]]; then
    current=`cat /tmp/CURRENTPATH | sed "s/\//_/g"` #added this as some consoles have a / in name, for example the Neo Geo core is listed as Neo Geo MVS/AES
    fullPath=`cat /tmp/FULLPATH`
    if [ "${current}" != "${lastPath}" ] && [ "${current}" != "" ]; then
      lastPath=`cat /tmp/CURRENTPATH`
      echo "Scrolling: ${current} - waiting for pause..."

      # Cancel the previous debounce job if still waiting
      if [ "${debounceJob}" != "" ]; then
        kill "${debounceJob}" 2>/dev/null
      fi

      # Start a new debounce: only send to Pixelcade after DEBOUNCE seconds of no new scroll events
      ( sleep ${DEBOUNCE} && echo "Settled on: ${current}" && lastCall="" && urlencode ${pixelcadeIP} ) &
      debounceJob=$!
    fi
  fi
done
