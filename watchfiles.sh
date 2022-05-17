#!/bin/bash

# watchfiles.sh
#
# A fancier "ls" with options to flag files based on certain criteria 
# and send listings via email.

SCRIPT_VERSION="22020517"

shopt -s lastpipe
shopt -s globstar

STYLE_RESET='\e[0m'
FORMAT_BOLD='\e[1m'
FORMAT_UNDERLINE='\e[4m'
COLOR_FG_BLACK='\e[30m'     
COLOR_FG_RED='\e[31m'
COLOR_FG_YELLOW='\e[33m'
COLOR_FG_BLUE='\e[34m'
COLOR_FG_GREY='\e[37m'
COLOR_FG_WHITE='\e[97m'
COLOR_BG_BLACK='\e[40m'     
COLOR_BG_RED='\e[41m'
COLOR_BG_BLUE='\e[44m'
COLOR_BG_GREY='\e[47m'
COLOR_BG_DGREY='\e[100m'

ShowHelp() {
    echo "Usage: ./watchfiles.sh [OPTION] ..."
    echo "List files recursively (the current directory by default)."
    echo
    echo "Mandatory arguments to long options are mandatory for short options too."
    echo
    echo "  -t, --target             Path to target directory if other than current."
    echo "                           NOTE: If your target path has wildcards or spaces, you"
    echo "                           will want to enclose the path in quotation marks."
    echo "  -p, --fileRegex          The regex pattern for including a file in the listing."
    echo "  -n, --minAgeAlert        Flag files that are at least this old (in minutes)."
    echo "  -N, --minAgeIgnore       Exclude from the listing files that are newer (in minutes)."
    echo "  -a, --maxAgeAlert        Flag files that are older than this (in minutes)."
    echo "  -A, --maxAgeIgnore       Exclude from the listing files that are older (in minutes)."
    echo "  -b, --minSizeAlert       Flag files that are smaller than this size (in kilobytes)."
    echo "  -B, --minSizeIgnore      Exclude from the listing files that are smaller (in kilobytes)."
    echo "  -k, --maxSizeAlert       Flag files that are larger than this size (in kilobytes)."
    echo "  -K, --maxSizeIgnore      Exclude from the listing files that are larger (in kilobytes)."
    echo "  -0, --zeroByteAlert      Flag files that are 0 bytes."
    echo "  -H, --suppressHeading    Do not show the listing heading block"
    echo "  -O, --showOptions        Show the command line options used as criteria for this"
    echo "                           listing as part of the listing heading block"
    echo "  -P, --plainText          Output contains no color or decoration escape codes."
    echo "  -s, --mailSubject        The subject line for emailed output."
    echo "                           ('Watchfiles Report' is the default.)"
    echo "  -f, --mailFrom           The address an emailed report should be sent from."
    echo "  -d, --mailDistribution   The distribution list of comma separated addresses the" 
    echo "                           email should be sent to."
    echo "  -e, --mailSuppressEmpty  An email will not be sent if the set criteria did not"
    echo "                           result in any files being listed."
    echo "  -S, --mailEmptySubject   The subject line of the email if no files are listed."
    echo "  -v, --version            Show script version"
}

ShowVersion() {
    echo "watchfiles.sh v$SCRIPT_VERSION"
    echo "by Tom Gehrke"
}

# Flushed gathered lines to the output variable
flushOutput () {
    if [[ $optPlainText == "true" ]]
    then
        dirLine="DIRECTORY - $currentDir\n"
        for i in {1..80}; do dirLine+="-"; done; dirLine+="\n"
    else
        dirLine="${FORMAT_UNDERLINE}DIRECTORY - $currentDir${STYLE_RESET}\n"
    fi
    fileLines="$currentFiles\n"
    output+="$dirLine"
    output+="$fileLines"
}

currentDir=""
currentFiles=""
currentTimeSSE=$(echo `date +%s`) # Seconds Since Epoch
filesFound=""

# Set option defaults
optRootPath="$PWD"
optFileRegex=""
optZeroByteAlert=""
optMinAgeAlert=0
optMinAgeIgnore=0
optMaxAgeAlert=$currentTimeSSE
optMaxAgeIgnore=$currentTimeSSE
optMinSizeAlert=0
optMinSizeIgnore=0
optMaxSizeAlert=0
optMaxSizeIgnore=0
optSuppressHeading=""
optShowOptions=""
optReportOnly=""
optPlainText=""
optMailSubject="Watchfiles Report"
optMailFrom=""
optMailDistribution=""
optMailSuppressEmpty=""
optMailEmptySubject=""

# Read arguments and update options
SHORT=h,t:,p:,n:,N:,a:,A:,0,H,O,P,s:,f:,d:,e,S:,b:,B:,k:,K:,v
LONG=help,target:,fileRegex:,minAgeAlert:,minAgeIgnore:,maxAgeAlert:,maxAgeIgnore:,zeroByteAlert,suppressHeading,showOptions,plainText,mailSubject:,mailFrom:,mailDistribution:,mailSuppressEmpty,mailEmptySubject:,minSizeAlert:,minSizeIgnore:,maxSizeAlert:,maxSizeIgnore:,version
OPTS=$(getopt -n watchfiles --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"

while :
do
    case "$1" in
        --help | -h )
            ShowHelp
            exit
            ;;

        --version | -v )
            ShowVersion
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

        --minAgeAlert | -n )
            optMinAgeAlert=$(( $2 * 60 ))
            shift 2
            ;;

        --minAgeIgnore | -N )
            optMinAgeIgnore=$(( $2 * 60 ))
            shift 2
            ;;

        --maxAgeAlert | -a )
            optMaxAgeAlert=$(( $2 * 60 ))
            shift 2
            ;;

        --maxAgeIgnore | -A )
            optMaxAgeIgnore=$(( $2 * 60 ))
            shift 2
            ;;

        --minSizeAlert | -b )
            optMinSizeAlert=$(( $2 * 1024 ))
            shift 2
            ;;

        --minSizeIgnore | -B )
            optMinSizeIgnore=$(( $2 * 1024 ))
            shift 2
            ;;

        --maxSizeAlert | -k )
            optMaxSizeAlert=$(( $2 * 1024 ))
            shift 2
            ;;

        --maxSizeIgnore | -K )
            optMaxSizeIgnore=$(( $2 * 1024 ))
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

        --mailSubject | s )
            optMailSubject="$2"
            shift 2
            ;;
        
        --mailFrom | f )
            optMailFrom="$2"
            shift 2
            ;;
        
        --mailDistribution | d )
            optMailDistribution="$2"

            # Force plain text output
            optPlainText="true"

            shift 2
            ;;

        --mailSuppressEmpty | e )
            optMailSuppressEmpty="true"
            shift;
            ;;

        --mailEmptySubject | S )
            optMailEmptySubject="$2"
            shift 2
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
    minAgeFlag="N"
    maxAgeFlag="A"
    minSizeFlag="B"
    maxSizeFlag="K"
    emptyFlag=" "
else
    zeroByteFlag="${COLOR_BG_GREY}${COLOR_FG_BLACK}${STYLE_BOLD}0${STYLE_RESET}"
    minAgeFlag="${COLOR_BG_RED}${COLOR_FG_WHITE}${STYLE_BOLD}N${STYLE_RESET}"
    maxAgeFlag="${COLOR_BG_RED}${COLOR_FG_YELLOW}${STYLE_BOLD}A${STYLE_RESET}"
    minSizeFlag="${COLOR_BG_BLUE}${COLOR_FG_WHITE}${STYLE_BOLD}B${STYLE_RESET}"
    maxSizeFlag="${COLOR_BG_BLUE}${COLOR_FG_YELLOW}${STYLE_BOLD}K${STYLE_RESET}"
    emptyFlag=" "
fi

if [[ $optSuppressHeading != "true" ]]
then
    for i in {1..80}; do heading+="~"; done; heading+="\n"
    heading+="FILE LISTING FOR $optRootPath\n"
    heading+="$(date)\n"

    options=""
    legend=""

    if [[ $optFileRegex != "" ]]
    then
        options+="- Only show files that match the regular expression: $optFileRegex\n"
    fi

    if [[ $optZeroByteAlert == "true" ]]
    then
        options+="- Flag empty ('zero byte') files\n"
        legend+="$zeroByteFlag=Zero Byte    "
    fi

    if [[ $optMinAgeAlert != 0 ]]
    then
        options+="- Flag files that are less than $(( $optMinAgeAlert / 60 )) minutes old\n"
        legend+="$minAgeFlag=Min Age    "
    fi

    if [[ $optMaxAgeAlert != $currentTimeSSE ]]
    then
        options+="- Flag files that are older than $(( $optMaxAgeAlert / 60 )) minutes old\n"
        legend+="$maxAgeFlag=Max Age    "
    fi

    if [[ $optMinAgeIgnore != 0 ]]
    then
        options+="- Do not list files that are less than $(( $optMinAgeIgnore / 60 )) minutes old\n"
    fi

    if [[ $optMaxAgeIgnore != $currentTimeSSE ]]
    then
        options+="- Do not list files that are older than $(( $optMaxAgeIgnore / 60 )) minutes old\n"
    fi

    if [[ $optMinSizeAlert != 0 ]]
    then
        options+="- Flag files that are smaller than $(( $optMinSizeAlert / 1024 ))KB\n"
        legend+="$minSizeFlag=Min Size    "
    fi

    if [[ $optMaxSizeAlert != 0 ]]
    then
        options+="- Flag files that are larger than $(( $optMaxSizeAlert / 1024 ))KB\n"
        legend+="$maxSizeFlag=Max Size    "
    fi

    if [[ $optMinSizeIgnore != 0 ]]
    then
        options+="- Do not list files that are not at least $(( $optMinSizeIgnore / 1024 ))KB\n"
    fi

    if [[ $optMaxSizeIgnore != 0 ]]
    then
        options+="- Do not list files that are larger than $(( $optMaxSizeIgnore / 1024 ))KB\n"
    fi

    if [[ $optSuppressHeading == "true" ]]
    then
        option+="- Suppress the report header block (How are you even seeing this?!)\n"
    fi

    if [[ $legend != "" ]]
    then
        heading+="\nLEGEND:\n"
        heading+="$legend\n"
    fi 

    if [[ $optShowOptions == "true" && $options != "" ]]
    then
        heading+="\nOPTIONS:\n"
        heading+="$options"
    fi
    for i in {1..80}; do heading+="~"; done; heading+="\n\n"
fi

output="$heading"

# Executes "ls" and redirects output to the loop
ls -hRltQ --time-style=long-iso --width=250 $optRootPath |
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

            if [[ "$fileName" =~ $optFileRegex ]]
            then
                fullPath="${currentDir}"/"${fileName}"
                fileAge=$(( $currentTimeSSE - `stat --format=%Y "$fullPath"` ))
                fileSize=$(echo `stat --format=%s "$fullPath"`)

                if [[ $fileAge -gt $optMinAgeIgnore \
                    && $fileAge -lt $optMaxAgeIgnore \
                    && ($optMinSizeIgnore = 0 || $fileSize -gt $optMinSizeIgnore) \
                    && ($optMaxSizeIgnore = 0 || $fileSize -lt $optMaxSizeIgnore) ]]
                then
                    
                    flagStack=""
                    
                    # Has the user asked for a minimum age alert?
                    if [ $optMinAgeAlert != 0 ]
                    then
                        # Is the file's age greater than the minimum threshold?
                        if [ $fileAge -lt $optMinAgeAlert ]
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

                    # Has the user asked for a minimum size alert?
                    if [ $optMinSizeAlert != 0 ]
                    then
                        # Is the file's age less than the minimum threshold?
                        if [ $fileSize -lt $optMinSizeAlert ]
                        then
                            flagStack+=$minSizeFlag
                        else
                            flagStack+=$emptyFlag
                        fi
                    fi

                    # Has the user asked for a maximum size alert?
                    if [ $optMaxSizeAlert != 0 ]
                    then
                        # Is the file's age greater than the maximum threshold?
                        if [ $fileSize -gt $optMaxSizeAlert ]
                        then
                            flagStack+=$maxSizeFlag
                        else
                            flagStack+=$emptyFlag
                        fi
                    fi

                    # Has the user asked for a zero byte alert?
                    if [[ $optZeroByteAlert == "true" ]]
                    then
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
                    filesFound="true"
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

if [[ "$optMailDistribution" != "" ]]
then
    if [[ $filesFound == "true" || $optMailSuppressEmpty != "true" ]]
    then
        subject="$optMailSubject"
        if [[ $filesFound != "true" ]]
        then
            subject="$optMailEmptySubject"
        fi
        
        echo -e "$output" | mailx -s "$subject" -r "$optMailFrom" "$optMailDistribution"
    fi
else
    echo -e "$output"
fi
