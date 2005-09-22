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
		echo "$0: Removing: $1/Contents/PkgInfo"
		rm -f "$1/Contents/PkgInfo"
		echo "$0: Removing: $1/Contents/"
		rmdir "$1/Contents/"
		echo "$0: Unsetting bundle bit"
		/Developer/Tools/SetFile -a b "$1"
	fi
fi
