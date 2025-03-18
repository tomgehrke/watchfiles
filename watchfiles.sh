#!/usr/bin/env bash

# watchfiles.sh
#
# Simple file age and size monitoring

SCRIPT_VERSION="25.03.16"

# ------------------------------------------
# Constants
# ------------------------------------------

# Styles
STYLE_RESET='\e[0m'
FORMAT_BOLD='\e[1m'
FORMAT_UNDERLINE='\e[4m'

# Foreground Colors
COLOR_FG_BLACK='\e[30m'
COLOR_FG_RED='\e[31m'
COLOR_FG_GREEN='\e[32m'         
COLOR_FG_YELLOW='\e[33m'
COLOR_FG_BLUE='\e[34m'
COLOR_FG_MAGENTA='\e[35m'       
COLOR_FG_CYAN='\e[36m'          
COLOR_FG_GREY='\e[37m'
COLOR_FG_WHITE='\e[97m'

# Bright Foreground Colors
COLOR_FG_BRIGHT_BLACK='\e[90m'  
COLOR_FG_BRIGHT_RED='\e[91m'    
COLOR_FG_BRIGHT_GREEN='\e[92m'  
COLOR_FG_BRIGHT_YELLOW='\e[93m' 
COLOR_FG_BRIGHT_BLUE='\e[94m'   
COLOR_FG_BRIGHT_MAGENTA='\e[95m'
COLOR_FG_BRIGHT_CYAN='\e[96m'   

# Background Colors
COLOR_BG_BLACK='\e[40m'
COLOR_BG_RED='\e[41m'
COLOR_BG_GREEN='\e[42m'         
COLOR_BG_YELLOW='\e[43m'        
COLOR_BG_BLUE='\e[44m'
COLOR_BG_MAGENTA='\e[45m'       
COLOR_BG_CYAN='\e[46m'          
COLOR_BG_WHITE='\e[47m'
COLOR_BG_DGREY='\e[100m'

# Bright Background Colors
COLOR_BG_BRIGHT_RED='\e[101m'   
COLOR_BG_BRIGHT_GREEN='\e[102m' 
COLOR_BG_BRIGHT_YELLOW='\e[103m' 
COLOR_BG_BRIGHT_BLUE='\e[104m'  
COLOR_BG_BRIGHT_MAGENTA='\e[105m' 
COLOR_BG_BRIGHT_CYAN='\e[106m'  
COLOR_BG_BRIGHT_WHITE='\e[107m' 

# Color Combinations
COLOR_TITLE="${COLOR_BG_BLUE}${COLOR_FG_WHITE}${FORMAT_BOLD}"
COLOR_STATUS="${COLOR_BG_BLACK}${COLOR_FG_WHITE}${FORMAT_BOLD}"
COLOR_DIR="${COLOR_BG_BRIGHT_CYAN}${COLOR_FG_BLACK}${FORMAT_BOLD}"
COLOR_ZEROBYTE="${COLOR_BG_BRIGHT_YELLOW}${COLOR_FG_BLACK}${FORMAT_BOLD}"
COLOR_MINAGE="${COLOR_BG_BLUE}${COLOR_FG_WHITE}${FORMAT_BOLD}"
COLOR_MAXAGE="${COLOR_BG_RED}${COLOR_FG_YELLOW}${FORMAT_BOLD}"
COLOR_MINSIZE="${COLOR_BG_BLUE}${COLOR_FG_WHITE}${FORMAT_BOLD}"
COLOR_MAXSIZE="${COLOR_BG_RED}${COLOR_FG_YELLOW}${FORMAT_BOLD}"

# Widths
SCREEN_WIDTH=$(tput cols)
AGE_WIDTH=5
SIZE_WIDTH=6
USER_WIDTH=10
GROUP_WIDTH=10
PERM_WIDTH=10

# Unit Constants
SECONDS_IN_MINUTE=60
SECONDS_IN_HOUR=$(( SECONDS_IN_MINUTE * 60 ))
SECONDS_IN_DAY=$(( SECONDS_IN_HOUR * 24 ))

MINUTES_IN_HOUR=60
MINUTES_IN_DAY=$(( MINUTES_IN_HOUR * 24 ))

BYTES_IN_KB=1024
BYTES_IN_MB=$(( BYTES_IN_KB * 1024 ))
BYTES_IN_GB=$(( BYTES_IN_MB * 1024 ))

# ------------------------------------------
# Variables & Defaults
# ------------------------------------------

output=""
currentDir=""
currentTimeSSE=$(date +%s) # Seconds Since Epoch
fileCount=0
outputTitle=""
outputStatus=""
outputHeading=""
outputListing=""

# Command-line option defaults
rootPath="$PWD"
title=""
fileRegex=""
zeroByteAlert=""
minAgeAlert=0
minAgeIgnore=0
maxAgeAlert=0
maxAgeIgnore=0
minSizeAlert=0
minSizeIgnore=0
maxSizeAlert=0
maxSizeIgnore=0
suppressHeading=""
showOptions=""

# ------------------------------------------
# Functions
# ------------------------------------------

showHelp() {
more <<EOF
Usage: ./watchfiles.sh [OPTION] ...

List files recursively (the current directory by default).

Mandatory arguments to long options are mandatory for short options too.

-t, --target            Path to target directory if other than current.
                        NOTE: If your target path has wildcards or spaces, you
                        will want to enclose the path in quotation marks.
-p, --fileRegex         The regex pattern for including a file in the listing.
-n, --minAgeAlert       Flag files that are at least this age in minutes.
                        You may also include an overriding time unit 
                        (examples: 10s, 10m, 10h, 10d).
-N, --minAgeIgnore      Exclude from the listing files that are newer (in minutes).
-a, --maxAgeAlert       Flag files that are older than this in minutes.
                        You may also include an overriding time unit 
                        (examples: 10s, 10m, 10h, 10d).
-A, --maxAgeIgnore      Exclude from the listing files that are older (in minutes).
-b, --minSizeAlert      Flag files that are smaller than this size (in kilobytes).
-B, --minSizeIgnore     Exclude from the listing files that are smaller (in kilobytes).
-k, --maxSizeAlert      Flag files that are larger than this size (in kilobytes).
-K, --maxSizeIgnore     Exclude from the listing files that are larger (in kilobytes).
-0, --zeroByteAlert     Flag files that are 0 bytes.
-H, --suppressHeading   Do not show the listing heading block
-O, --showOptions       Show the command line options used as criteria for this
                        listing as part of the listing heading block
-P, --plainText         Output contains no color or decoration escape codes.
-v, --version           Show script version
-T, --title             Adds a title line at the top of the output
EOF
}

showVersion() {
cat <<EOF
watchfiles.sh v$SCRIPT_VERSION
by Tom Gehrke
EOF
}

readOptions() {
    # Read arguments and update options
    SHORT=h,t:,p:,n:,N:,a:,A:,0,H,O,P,b:,B:,k:,K:,v,T:
    LONG=help,target:,fileRegex:,minAgeAlert:,minAgeIgnore:,maxAgeAlert:,maxAgeIgnore:,zeroByteAlert,suppressHeading,showOptions,plainText,minSizeAlert:,minSizeIgnore:,maxSizeAlert:,maxSizeIgnore:,version,title:
    OPTS=$(getopt -n watchfiles --options $SHORT --longoptions $LONG -- "$@")

    eval set -- "$OPTS"

    while true; do
        case "$1" in
            --help | -h )
                showHelp
                exit
                ;;
            --version | -v )
                showVersion
                exit
                ;;
            --target | t )
                rootPath="$2"
                shift 2
                ;;
            --zeroByteAlert | -0 )
                zeroByteAlert="y"
                shift
                ;;
            --minAgeAlert | -n )
                if [[ ! $2 =~ ^[0-9]+[sSmMhHdD]?$ ]]; then
                    echo "Invalid time format for minAgeAlert: $2"
                    exit 1
                fi
                minAgeAlert=$( convertToSeconds $2 )
                shift 2
                ;;
            --maxAgeAlert | -a )
                if [[ ! $2 =~ ^[0-9]+[sSmMhHdD]?$ ]]; then
                    echo "Invalid time format for maxAgeAlert: $2"
                    exit 1
                fi
                maxAgeAlert=$( convertToSeconds $2 )
                shift 2
                ;;
            --minAgeIgnore | -N )
                if [[ ! $2 =~ ^[0-9]+[mMhHdD]?$ ]]; then
                    echo "Invalid time format for minAgeIgnore: $2"
                    exit 1
                fi
                minAgeIgnore=$( convertToMinutes $2 )
                shift 2
                ;;
            --maxAgeIgnore | -A )
                if [[ ! $2 =~ ^[0-9]+[mMhHdD]?$ ]]; then
                    echo "Invalid time format for minAgeIgnore: $2"
                    exit 1
                fi
                maxAgeIgnore=$( convertToMinutes $2 )
                shift 2
                ;;
            --minSizeAlert | -b )
                if [[ ! $2 =~ ^[0-9]+[bBkKmMgG]?$ ]]; then
                    echo "Invalid size format for minSizeAlert: $2"
                    exit 1
                fi
                minSizeAlert=$( convertToBytes $2 )
                shift 2
                ;;
            --maxSizeAlert | -k )
                if [[ ! $2 =~ ^[0-9]+[bBkKmMgG]?$ ]]; then
                    echo "Invalid size format for maxSizeAlert: $2"
                    exit 1
                fi
                maxSizeAlert=$( convertToBytes $2 )
                shift 2
                ;;
            --minSizeIgnore | -B )
                if [[ ! $2 =~ ^[0-9]+[bBkKmMgG]?$ ]]; then
                    echo "Invalid size format for minSizeIgnore: $2"
                    exit 1
                fi
                minSizeIgnore=$( convertToBytes $2 )
                shift 2
                ;;
            --maxSizeIgnore | -K )
                if [[ ! $2 =~ ^[0-9]+[bBkKmMgG]?$ ]]; then
                    echo "Invalid size format for maxSizeIgnore: $2"
                    exit 1
                fi
                maxSizeIgnore=$( convertToBytes $2 )
                shift 2
                ;;
            --fileRegex | p )
                fileRegex="$2"
                shift 2
                ;;
            --suppressHeading | H )
                suppressHeading="y"
                shift
                ;;
            --showOptions | O )
                showOptions="y"
                shift
                ;;
            --plainText | P )
                setPlainText
                shift
                ;;
            --title | T )
                title="$2"
                shift 2
                ;;
            -- )
                shift;
                break
                ;;
        esac
    done
}

convertToSeconds() {
    # Minutes is the default unit
    local timeString=$1
    local timeInSeconds=0
    local timeUnit=${timeString: -1}
    local timeValue=${timeString%?}

    case $timeUnit in
        s|S) timeInSeconds=$timeValue ;;
        m|M) timeInSeconds=$(( $timeValue * SECONDS_IN_MINUTE )) ;;
        h|H) timeInSeconds=$(( $timeValue * SECONDS_IN_HOUR )) ;;
        d|D) timeInSeconds=$(( $timeValue * SECONDS_IN_DAY )) ;;
        *) timeInSeconds=$(( $timeString * SECONDS_IN_MINUTE )) ;;
    esac

    echo $timeInSeconds
}

convertToMinutes() {
    # Minutes is the default unit
    local timeString=$1
    local timeInMinutes=0
    local timeUnit=${timeString: -1}
    local timeValue=${timeString%?}

    case $timeUnit in
        m|M) timeInMinutes=$timeValue ;;
        h|H) timeInMinutes=$(( $timeValue * MINUTES_IN_HOUR )) ;;
        d|D) timeInMinutes=$(( $timeValue * MINUTES_IN_DAY )) ;;
        *) timeInMinutes=$timeString ;;
    esac

    echo $timeInMinutes
}

convertToBytes() {
    # Kilobytes is the default unit
    local sizeString=$1
    local sizeInBytes=0
    local sizeUnit=${sizeString: -1}
    local sizeValue=${sizeString%?}

    case $sizeUnit in
        b|B) sizeInBytes=$sizeValue ;;
        k|K) sizeInBytes=$(( $sizeValue * BYTES_IN_KB )) ;;
        m|M) sizeInBytes=$(( $sizeValue * BYTES_IN_MB )) ;;
        g|G) sizeInBytes=$(( $sizeValue * BYTES_IN_GB )) ;;
        *) sizeInBytes=$(( $sizeString * BYTES_IN_KB )) ;;
    esac

    echo $sizeInBytes
}

setOutputTitle() {
    if [[ -z "$title" ]]; then
        title="Watchfiles Report"
    fi

    printf -v title "%*s" $(( (${#title} + $SCREEN_WIDTH) / 2)) "$title"
    printf -v title "%-*s" $SCREEN_WIDTH "$title"
    
    outputTitle="${COLOR_TITLE}$title${STYLE_RESET}"
}

setOutputStatus() {
    local status=" $fileCount files listed "

    printf -v status "%${SCREEN_WIDTH}s" "$status"

    outputStatus="${COLOR_STATUS}$status${STYLE_RESET}"
}

makeLine() {
    local line=""
    local lineChar="${1:-=}"
    for i in $(seq $SCREEN_WIDTH); do line+=$lineChar; done
    echo -e "$line"
}

getOptions() {
    local options=""

    if [[ $showOptions != "y" ]]; then
        return
    fi
    
    if [[ -n $fileRegex ]]; then
        options+="- Only show files that match the regular expression: $fileRegex"$'\n'
    fi

    if [[ $zeroByteAlert == "y" ]]; then
        options+="- Flag empty ('zero byte') files"$'\n'
    fi

    if (( $minAgeAlert > 0 )); then
        options+="- Flag files that are less than $minAgeAlert seconds old"$'\n'
    fi

    if (( $maxAgeAlert > 0 )); then
        options+="- Flag files that are older than $maxAgeAlert seconds old"$'\n'
    fi

    if (( $minAgeIgnore > 0 )); then
        options+="- Do not list files that are less than $minAgeIgnore minutes old"$'\n'
    fi

    if (( $maxAgeIgnore > 0 )); then
        options+="- Do not list files that are older than $maxAgeIgnore minutes old"$'\n'
    fi

    if (( $minSizeAlert > 0 )); then
        options+="- Flag files that are smaller than $(( $minSizeAlert / 1024 ))KB"$'\n'
    fi

    if (( $maxSizeAlert > 0 )); then
        options+="- Flag files that are larger than $(( $maxSizeAlert / 1024 ))KB"$'\n'
    fi

    if (( $minSizeIgnore > 0 )); then
        options+="- Do not list files that are not at least $(( $minSizeIgnore / 1024 ))KB"$'\n'
    fi

    if (( $maxSizeIgnore > 0 )); then
        options+="- Do not list files that are larger than $(( $maxSizeIgnore / 1024 ))KB"$'\n'
    fi

    if [[ $suppressHeading == "y" ]]; then
        options+="- Suppress the report header block (How are you even seeing this?!)"$'\n'
    fi

    if [[ $options == "" ]]; then
        return
    fi
    
    echo -e "\nOptions:\n$options"
}

getLegend() {
    local legend=""

    if [[ $zeroByteAlert == "y" ]]; then
        legend+="${COLOR_ZEROBYTE} Zero Byte File ${STYLE_RESET} "
    fi

    if  (( $minAgeAlert > 0 )); then
        legend+="${COLOR_MINAGE} < Min Age ${STYLE_RESET} "
    fi

    if (( $maxAgeAlert > 0 )); then
        legend+="${COLOR_MAXAGE} >= Max Age ${STYLE_RESET} "
    fi

    if (( $minSizeAlert > 0 )); then
        legend+="${COLOR_MINSIZE} < Min Size ${STYLE_RESET} "
    fi

    if (( $maxSizeAlert > 0 )); then
        legend+="${COLOR_MAXSIZE} >= Max Size ${STYLE_RESET} "
    fi

    if [[ -z $legend ]]; then
        return
    fi

    echo -e "\nLegend: $legend"
}

setOutputHeading() {
    if [[ $suppressHeading = "y" ]]; then
        return
    fi

    local heading=" "$'\n'
    local options=$(getOptions)
    local legend=$(getLegend)

    # heading+=$(makeLine)
    heading+="File listing for $rootPath"$'\n'
    heading+=$(date)$'\n'

    if [[ -n $options ]]; then
        heading+="$options"$'\n'
    fi

    if [[ -n $legend ]]; then
        heading+=$(getLegend)$'\n'
    fi

    outputHeading="$heading"
}

getBasicAge() {
    local ageInseconds=$1
    local days hours minutes
    
    days=$(( ageInseconds / SECONDS_IN_DAY ))
    hours=$(( ( ageInseconds % SECONDS_IN_DAY ) / SECONDS_IN_HOUR ))
    minutes=$(( ( ageInseconds % SECONDS_IN_HOUR ) / SECONDS_IN_MINUTE ))

    # Output the largest unit using (( )) for conditions
    if (( days > 0 )); then
        echo "${days}d"
    elif (( hours > 0 )); then
        echo "${hours}h"
    elif (( minutes > 0 )); then
        echo "${minutes}m"
    else
        echo "${ageInSeconds}s"
    fi    
}

formatSizeAlert() {
    local sizeInBytes=$1
    local numberFormat="$(numfmt --to=iec --suffix=B $sizeInBytes)"
    local formattedSize=$(printf " %${SIZE_WIDTH}s " "${numberFormat:0:-1}")
    
    if [[ $zeroByteAlert == "y" && $sizeInBytes == "0" ]]; then
        formattedSize="${COLOR_ZEROBYTE}$formattedSize${STYLE_RESET}"
    elif (( minSizeAlert > 0 )) && (( sizeInBytes < minSizeAlert )); then
        formattedSize="${COLOR_MINSIZE}$formattedSize${STYLE_RESET}"
    elif (( maxSizeAlert > 0 )) && (( sizeInBytes >= maxSizeAlert )); then
        formattedSize="${COLOR_MAXSIZE}$formattedSize${STYLE_RESET}"
    fi

    echo "$formattedSize"
}

formatAgeAlert() {
    local ageInSeconds=$1
    formattedAge=$(printf " %${AGE_WIDTH}s " "$(getBasicAge $ageInSeconds)")
    
    if (( minAgeAlert > 0 )) && (( ageInSeconds < minAgeAlert )); then
        formattedAge="${COLOR_MINAGE}$formattedAge${STYLE_RESET}"
    elif (( maxAgeAlert > 0 )) && (( ageInSeconds >= maxAgeAlert )); then
        formattedAge="${COLOR_MAXAGE}$formattedAge${STYLE_RESET}"
    fi

    echo "$formattedAge"
}

setOutputListing() {
    local listing=""
    local depth path file age currentDirectory
    local findCommand="find $rootPath -path '*/.*' -prune -o -type f"

    if [[ -n $fileRegex ]]; then
        findCommand+=" -regextype posix-extended -regex '.*/$fileRegex'"
    fi

    if (( $minAgeIgnore > 0 )); then
        findCommand+=" -mmin +$minAgeIgnore"
    fi

    if (( $maxAgeIgnore > 0 )); then
        findCommand+=" -mmin -$maxAgeIgnore"
    fi

    findCommand+=" -printf \"%h\\\t%f\\\t%s\\\t%T@\\\t%u\\\t%g\\\t%M\\\n\" 2>/dev/null"
    findResults=$(eval $findCommand | sort --field-separator=$'\t' --ignore-case -k1,1 -k2,2)
    
    # echo "$findCommand"

    if [[ -z $findResults ]]; then
        return
    fi

    while IFS=$'\t' read -r path file sizeInBytes lastModifiedSSE userName groupName permissions; do
        ageInSeconds=$(( $currentTimeSSE - ${lastModifiedSSE%.*} ))
        flags=""

        if [[ "$path" != "$currentDirectory" ]]; then
            currentDirectory="$path"
            listing+=$'\n'$(printf "${COLOR_DIR}%-${SCREEN_WIDTH}s${STYLE_RESET}" "$currentDirectory")$'\n'
        fi
        
        fileWidth=$(( SCREEN_WIDTH - AGE_WIDTH - SIZE_WIDTH - USER_WIDTH - GROUP_WIDTH - PERM_WIDTH - 16 ))
        listing+=$(printf "%-${fileWidth}s │%${AGE_WIDTH}s│%${SIZE_WIDTH}s│ %-${USER_WIDTH}s │ %-${GROUP_WIDTH}s │ %${PERM_WIDTH}s" "${file:0:$fileWidth}" "$(formatAgeAlert "$ageInSeconds")" "$(formatSizeAlert "$sizeInBytes")" "${userName:0:$USER_WIDTH}" "${groupName:0:$GROUP_WIDTH}" "$permissions")$'\n'
        (( fileCount++ ))
    done <<< "$findResults"

    outputListing="$listing"
}

readOptions "$@"
setOutputTitle
setOutputHeading
setOutputListing
setOutputStatus

echo -e "${outputTitle}\n${outputHeading}\n${outputListing}\n$outputStatus"