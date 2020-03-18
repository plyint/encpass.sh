#!/bin/sh

case1() {
	case "$1" in
		case2 "$1" )
			;;
		add )
			;;
		delete )
			echo "FIRST"
			;;
		remove )
			;;
	esac
}
		
case2() {
		add )
			;;
		delete )
			echo "SECOND"
			;;
		remove )
			;;
}
		
case1 "$1"
