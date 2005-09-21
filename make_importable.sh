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
		mkdir "$1/Contents/"
		echo -n 'DRep????' > "$1/Contents/PkgInfo"
		/Developer/Tools/SetFile -a B "$1"
	fi
fi
