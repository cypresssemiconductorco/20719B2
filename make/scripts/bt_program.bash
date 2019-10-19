#!/bin/bash
(set -o igncr) 2>/dev/null && set -o igncr; # this comment is required
set -e

#######################################################################################################################
# This script is designed to program BT devices via HCI.
#
# usage:
# 	bt_program.bash --shell=<modus shell path>
#					--tools=<wiced tools path>
#					--scripts=<wiced scripts path>
#					--elf=<app elf file>
#					--hex=<download hex file>
#					--verbose
#
#######################################################################################################################

USAGE="(-s=|--shell=)<shell path> (-t=|--tools=)<wiced tools path> (-w=|--scripts=)<wiced scripts path> (-x=|--hex=)<hex file> (-e=|--elf=)<elf file>"
if [[ $# -eq 0 ]]; then
	echo "usage: $0 $USAGE"
	exit 1
fi

for i in "$@"
do
	case $i in
		-s=*|--shell=*)
			CYMODUSSHELL="${i#*=}"
			shift
			;;
		-t=*|--tools=*)
			CYWICEDTOOLS="${i#*=}"
			CYWICEDTOOLS=${CYWICEDTOOLS//\\/\/}
			shift
			;;
		-w=*|--scripts=*)
			CYWICEDSCRIPTS="${i#*=}"
			CYWICEDSCRIPTS=${CYWICEDSCRIPTS//\\/\/}
			shift
			;;
		-e=*|--elf=*)
			CY_APP_ELF_ABS="${i#*=}"
			CY_APP_ELF_ABS=${CY_APP_ELF_ABS//\\/\/}
			shift
			;;
		-x=*|--hex=*)
			CY_APP_HEX_ABS="${i#*=}"
			CY_APP_HEX_ABS=${CY_APP_HEX_ABS//\\/\/}
			shift
			;;
		-v|--verbose)
			VERBOSE=1
			shift
			;;
		-h|--help)
			HELP=1
			echo "usage: $0 $USAGE"
			exit 1
			;;
		*)
			echo "bad parameter $i"
			echo "usage: $0 $USAGE"
			exit 1
			;;
	esac
done

# previously there was a conversion to relative path here
CY_APP_HEX=$CY_APP_HEX_ABS
CY_APP_ELF=$CY_APP_ELF_ABS

if [ "$VERBOSE" != "" ]; then
	echo "Script: bt_program.bash"
	echo "1: CYMODUSSHELL : $CYMODUSSHELL"
	echo "2: CYWICEDTOOLS : $CYWICEDTOOLS"
	echo "3: CYWICEDSCRIPTS : $CYWICEDSCRIPTS"
	echo "4: CY_APP_HEX  : $CY_APP_HEX"
	echo "5: CY_APP_ELF  : $CY_APP_ELF"
fi

# intercept this "program" target
if [ "$CY_PROGRAM_PACKAGE" != "" ]; then
    exit 0
fi



# check that required files are present
if [ ! -e "$CY_APP_ELF" ]; then
    echo "Elf file $CY_APP_ELF not found"
    echo "$CY_APP_HEX may be stale, try to clean and rebuild all"
    echo "Download failed"
    exit 1
fi
if [ ! -e "$CY_APP_HEX" ]; then
    echo "Download file $CY_APP_HEX not found, aborting download!"
    echo "Try to clean and rebuild all"
    echo "Download failed"
    exit 1
fi

dir=${CY_APP_HEX%/*}
if [ "$DIRECT_LOAD" = "true" ]; then
	echo "downloading image for direct ram load (*.hcd)"
	CY_APP_HEX=$(CY_APP_HEX//.hex/.hcd)
fi

# Extract the app name from the elf
APPNAME_BASE=$(basename ${CY_APP_ELF%.*})

CYWICEDBTP="$dir/"$APPNAME_BASE".btp"
CYWICEDID="$dir/"$APPNAME_BASE"_hci_id.txt"
CYWICEDMINI="$dir/minidriver.hex"
CYWICEDFLAGS="$dir/chipload_flags.txt"

set +e

# set up some tools that may be native and not modus-shell
CY_TOOL_PERL=perl
if ! type "$CY_TOOL_PERL" > /dev/null; then
CY_TOOL_PERL=$CYMODUSSHELL/bin/perl
fi

"$CY_TOOL_PERL" "$CYWICEDSCRIPTS/ChipLoad.pl" -tools_path $CYWICEDTOOLS -build_path $dir -id $CYWICEDID -btp $CYWICEDBTP \
                            -mini $CYWICEDMINI -hex $CY_APP_HEX -flags $CYWICEDFLAGS

if [ $? -eq 0 ]; then
   echo "Download succeeded"
else
   echo "Download failed"
   echo
   echo "If you have issues downloading to the kit, follow the steps below -"
   echo
   echo "Press and hold the 'Recover' button on the kit."
   echo "Press and hold the 'Reset' button on the kit."
   echo "Release the 'Reset' button."
   echo "After one second, release the 'Recover' button."
   exit 1
fi