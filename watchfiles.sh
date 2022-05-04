#!/bin/bash

# watchfiles.sh
#
# A fancier "ls" with options to flag files based on certain criteria.

shopt -s lastpipe

COLOR_RESET='\e[0m'
BOLD='\e[1m'
UNDERLINE='\e[4m'
RED='\e[31m'
BLACK='\e[30m'     
BLUE='\e[34m'
WHITE='\e[37m'

ShowHelp() {
    echo "Usage: ./watchfiles.sh [OPTION] ..."
    echo "List files recursively (the current directory by default)."
    echo
    echo "Mandatory arguments to long options are mandatory for short options too."
    echo
    echo "  -t, --target           Path to target directory if other than current."
    echo "                         NOTE: If your target path has wildcards or spaces, you"
    echo "                         will want to enclose the path in quotation marks."
    echo "  -p, --fileRegex        The regex pattern for including a file in the listing."
    echo "  -a, --minAgeAlert      Flag files that are at least this old (in minutes)."
    echo "  -A, --minAgeIgnore     Exclude from the listing files that are newer (in minutes)."
    echo "  -x, --maxAgeAlert      Flag files that are older than this (in minutes)."
    echo "  -X, --maxAgeIgnore     Exclude from the listing files that are older (in minutes)."
    echo "  -0, --zeroByteAlert    Flag files that are 0 bytes."
    echo "  -H, --suppressHeading  Do not show the listing heading block"
    echo "  -O, --showOptions      Show the command line options used as criteria for this"
    echo "                         listing as part of the listing heading block"
    echo "  -P, --plainText        Output contains no color or decoration escape codes."
}

# Flushed gathered lines to the output variable
flushOutput () {
    if [[ $optPlainText == "true" ]]
    then
        dirLine="DIRECTORY - $currentDir\n"
        for i in {1..80}; do dirLine+="-"; done; dirLine+="\n"
    else
        dirLine="${UNDERLINE}DIRECTORY - $currentDir${COLOR_RESET}\n"
    fi
    fileLines="$currentFiles\n"
    output+="$dirLine"
    output+="$fileLines"
}

currentDir=""
currentFiles=""
currentTimeSSE=$(echo `date +%s`) # Seconds Since Epoch

# Set option defaults
optRootPath="$PWD"
optFileRegex=""
optZeroByteAlert=""
optMinAgeAlert=0
optMinAgeIgnore=0
optMaxAgeAlert=$currentTimeSSE
optMaxAgeIgnore=$currentTimeSSE
optSuppressHeading=""
optShowOptions=""
optReportOnly=""
optPlainText=""

# Read arguments and update options
SHORT=h,t:,p:,a:,A:,x:,X:,0,H,O,P
LONG=help,target:,fileRegex:,minAgeAlert:,minAgeIgnore:,maxAgeAlert:,maxAgeIgnore:,zeroByteAlert,suppressHeading,showOptions,plainText
OPTS=$(getopt -n watchfiles --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"

while :
do
    case "$1" in
        --help | -h )
            ShowHelp
            exit
            ;;

        --target | t )
            optRootPath="$2"
            shift 2
            ;;

        --zeroByteAlert | -0 )
            optZeroByteAlert="true"
            shift
            ;;

        --minAgeAlert | -a )
            optMinAgeAlert=$(( $2 * 60 ))
            shift 2
            ;;

        --minAgeIgnore | -A )
            optMinAgeIgnore=$(( $2 * 60 ))
            shift 2
            ;;

        --maxAgeAlert | -x )
            optMaxAgeAlert=$(( $2 * 60 ))
            shift 2
            ;;

        --maxAgeIgnore | -X )
            optMaxAgeIgnore=$(( $2 * 60 ))
            shift 2
            ;;

        --fileRegex | p )
            optFileRegex="$2"
            shift 2
            ;;

        --suppressHeading | H )
            optSuppressHeading="true"
            shift
            ;;

        --showOptions | O )
            optShowOptions="true"
            shift
            ;;

        --plainText | P )
            optPlainText="true"
            shift
            ;;

        -- )
            shift;
            break
            ;;

    esac
done

heading=""

# Set values based on color output status
if [[ $optPlainText == "true" ]]
then
    zeroByteFlag="0"
    minAgeFlag="A"
    maxAgeFlag="X"
    emptyFlag=" "
else
    zeroByteFlag="${BLUE}0${COLOR_RESET}"
    minAgeFlag="${RED}A${COLOR_RESET}"
    maxAgeFlag="${RED}X${COLOR_RESET}"
    emptyFlag=" "
fi

if [[ $optSuppressHeading != "true" ]]
then
    for i in {1..80}; do heading+="#"; done; heading+="\n"
    heading+="FILE LISTING FOR $optRootPath\n"
    heading+="$(date)\n"
    if [[ $optShowOptions == "true" ]]
    then
        options=""

        if [[ $optFileRegex != "" ]]
        then
            options+="- Only show files that match the regular expression: $optFileRegex\n"
        fi

        if [[ $optZeroByteAlert == "true" ]]
        then
            options+="- Flag empty ('zero byte') files (flag = $zeroByteFlag)\n"
        fi

        if [[ $optMinAgeAlert != 0 ]]
        then
            options+="- Flag files that are at least $(( $optMinAgeAlert / 60 )) minutes old (flag = $minAgeFlag)\n"
        fi

        if [[ $optMaxAgeAlert != $currentTimeSSE ]]
        then
            options+="- Flag files that are older than $(( $optMaxAgeAlert / 60 )) minutes old (flag = $maxAgeFlag)\n"
        fi

        if [[ $optMinAgeIgnore != 0 ]]
        then
            options+="- Do not list files that are not at least $(( $optMinAgeIgnore / 60 )) minutes old\n"
        fi

        if [[ $optMaxAgeIgnore != $currentTimeSSE ]]
        then
            options+="- Do not list files that are older than $(( $optMaxAgeIgnore / 60 )) minutes old\n"
        fi

        if [[ $optSuppressHeading == "true" ]]
        then
            option+="- Suppress the report header block (How are you even seeing this?!)\n"
        fi

        if [[ $options != "" ]]
        then
            for i in {1..40}; do heading+="="; done; heading+="\n"
            heading+="OPTIONS:\n\n"
            heading+="$options"
        fi
    fi
    for i in {1..80}; do heading+="#"; done; heading+="\n\n"
fi

output="$heading"

# Executes "ls" and redirects output to the loop
ls -hRltQ --full-time --time-style=long-iso --width=250 $optRootPath |
while IFS= read -r line
do
    # See if the last character in the line is a ":" because that means we've entered a new directory
    if [[ "${line: -1}" == ":" ]]
    then
        # If we have already been through this once, we may have files queued. Flush them.
        if [[ "$currentFiles" != "" ]]
        then
            flushOutput
        fi

        # Set current directory
        dirPattern="^\"(.*)\":$"
        [[ "$line" =~ $dirPattern ]]
        currentDir="${BASH_REMATCH[1]}"

        # Reset file queue
        currentFiles=""
    else
        # Add a file to the list if the current line:
        # - is not blank
        # - does not start with "total"
        # - is not a directory
        if [[ "$line" != "" && "${line:0:5}" != "total" && "${line:0:1}" != "d" ]]
        then
            filePattern="\"(.*)\"$"
            [[ "$line" =~ $filePattern ]]
            fileName="${BASH_REMATCH[1]}"

            if [[ "$fileName" =~ "$optFileRegex" ]]
            then
                fullPath="${currentDir}"/"${fileName}"
                fileAge=$(( $currentTimeSSE - `stat --format=%Y "$fullPath"` ))

                if [[ $fileAge -gt $optMinAgeIgnore && $fileAge -lt $optMaxAgeIgnore ]]
                then
                    
                    flagStack=""
                    
                    # Has the user asked for a minimum age alert?
                    if [ $optMinAgeAlert -gt 0 ]
                    then
                        # Is the file's age greater than the minimum threshold?
                        if [ $fileAge -gt $optMinAgeAlert ]
                        then
                            flagStack+=$minAgeFlag
                        else
                            flagStack+=$emptyFlag
                        fi
                    fi

                    # Has the user asked for a maximum age alert?
                    if [ $optMaxAgeAlert -lt $currentTimeSSE ]
                    then
                        # Is the file's age greater than the maximum threshold?
                        if [ $fileAge -gt $optMaxAgeAlert ]
                        then
                            flagStack+=$maxAgeFlag
                        else
                            flagStack+=$emptyFlag
                        fi
                    fi

                    # Has the user asked for a zero byte alert?
                    if [[ $optZeroByteAlert == "true" ]]
                    then
                        # Grabbing the file size (in bytes) now that we need it
                        fileSize=$(echo `stat --format=%s "$fullPath"`)
                        if [ $fileSize == 0 ]
                        then
                            flagStack+=$zeroByteFlag
                        else
                            flagStack+=$emptyFlag
                        fi
                    fi

                    # printf -v fileLine '[%s] %s\n' "$flagStack" "$line"
                    if [[ "$flagStack" != "" ]]
                    then
                        currentFiles+="[$flagStack] "
                    fi
                    currentFiles+="$line\n"
                fi
            fi
        fi
    fi
done

# We're through the loop and need a final flush
# (assuming there is anything to flush)
if [[ "$currentDir" != "" && "$currentFiles" != "" ]]
then
    flushOutput
fi

echo -e "$output"
