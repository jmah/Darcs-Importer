#!/bin/sh

if [ "`basename "$1"`" != "_darcs" ]
then
	echo "Usage: $0 <_darcs directory>"
	exit 127
else
	if [ ! -d "$1" ]
	then
		echo "$0: $1: Directory not found"
		exit 127
	else
		echo "$0: Creating: $1/Contents/"
		mkdir "$1/Contents/"
		echo "$0: Creating: $1/Contents/PkgInfo"
		echo -n 'DRep????' > "$1/Contents/PkgInfo"
		echo "$0: Setting bundle bit"
		/Developer/Tools/SetFile -a B "$1"
		echo "$0: Running mdimport"
		mdimport "$1"
	fi
fi
