#!/bin/bash

set -e

###############################################################################
#
# This script will arrange photos and movies by its creation year and month
#
###############################################################################

# Get input dir
# Get output dir

# Example:
#
# ./photo-arranger.sh -src /mnt/photos -dest /home/erik/photos
#
# find all files from input dir
## for each file do
### verify valid file (JPG, PNG, GIF, TIF, MOV, MP4 etc etc)
### run exiftool to extract date times
### generate new dir in "output dir" like ${OUTPUT_DIR}/${YEAR}/${MONTH}
### calculate MD5sum
### check if file with the same name already is present in the same dir
#### if yes, compare MD5sum. If same -> just skip copy. If not same -> try rename file by adding a suffix "${NAME]_00.${EXT}"
##### check if name is unique and if not, just increase the running number and check again.
### copy file to that output-dir
### append to log file in "output dir" (photo-arranger.log)
#### <original file> | <copied file> | <md5 sum>

log() {
    WHEN=$(date +"%T")
    echo -e "$1 [$WHEN] $2" 1>&2
}

logError() {
    log "[\e[1;31mERROR\e[0m]" "$1"
}

logInfo() {
    log "[ \e[32mINFO\e[0m]" "$1"
}

logWarn() {
    log "[ \e[1;33mWARN\e[0m]" "$1"
}

logDebug() {
    if [ "${DEBUG}" == "true" ]; then
        log "[\e[34mDEBUG\e[0m]" "$1"
    fi
}

isValidDate() {
    DATE=$1
    [ -n "${DATE}" ] && \
        [ "${DATE}" != "-" ] && \
        [ "${DATE}" != "0000 00 00 00 00 00" ] && \
        [ "${DATE}" != "0000:00:00 00:00:00" ]
}

extractDates() {
    local DATE_FORMAT="%Y %m %d %H %M %S"
    local DATE
    local FOUND=false

    for EXIF_TAG in "CreateDate" "DateTimeOriginal" "FileModifyDate" ; do
        DATE=$(exiftool -s3 -$EXIF_TAG -d "$DATE_FORMAT" "$1")
        if ! isValidDate "$DATE" ; then
            logDebug "Tag $EXIF_TAG did not contain a valid date value ($DATE)"
        else
            logDebug "Tag $EXIF_TAG returned date $DATE"
            FOUND=true
            break
        fi
    done

    if ! $FOUND ; then
        logError "Unable to get create date from file $1. Aborting."
        exit 1
    fi
    
    echo $DATE
}

md5() {
    echo $(md5sum "$1" | cut -d ' ' -f 1)
}

compareChecksums() {
    MD5_SRC=$(md5 "${1}")
    MD5_DEST=$(md5 "${2}")
    [ "${MD5_SRC}" == "${MD5_DEST}" ]
}

processFile() {
	FN=$(basename "$1")

	logInfo "Processing file: \e[32m$1\e[0m"
	if [ ! -e "$1" ] || [ ${#FN} == 0 ] ; then
		return 1
	fi

    # Verify file extension
	FILE_EXT=${FN##*.}
    FILE_EXT_LC=$(echo "$FILE_EXT" | tr '[:upper:]' '[:lower:]')
    case $FILE_EXT_LC in 
        jpg|gif|png|jpeg|mov|mp4|mpg)
            # File extension ok
            ;;
        *)
            logWarn "File extension ${FILE_EXT} not supported. Ignoring file: ${FN}"
            return
    esac

    #DN=$(dirname $1)
    #RELDIR=${DN#"$INPUT_DIR"}
	FILE_PFX="${FN%.*}"
	DATES=($(extractDates "$1"))
    DEST_DIR="${OUTPUT_DIR}/${DATES[0]}/${DATES[1]}"
    DEST_FILE="${DEST_DIR}/${FILE_PFX}.${FILE_EXT}"

    if [ ! -d "${DEST_DIR}" ]; then
        logInfo "Creating directory ${DEST_DIR}"
        if ${DRY_RUN} ; then
            logInfo ">> mkdir -p ${DEST_DIR}"
        else
            mkdir -p ${DEST_DIR}
        fi
    fi

    idx=1
    while [[ $idx -le 20 ]]; do
        if [ ! -e "${DEST_FILE}" ]; then

            case $OPERATION in
                "copy")
                    logInfo "Copying ${1} to ${DEST_FILE}"
                    if ${DRY_RUN} ; then
                        logInfo ">> cp ${1} ${DEST_FILE}"
                    else
                        cp "${1}" "${DEST_FILE}"
                    fi
                    ;;
                "move")
                    logInfo "Moving ${1} to ${DEST_FILE}"
                    if ${DRY_RUN} ; then
                        logInfo ">> mv ${1} ${DEST_FILE}"
                    else
                        mv "${1}" "${DEST_FILE}"
                    fi
                    ;;
            esac

            return 0
        fi         

        logDebug "Dest file ${DEST_FILE} exists. Will compare MD5 checksum."
        if compareChecksums "$1" "$DEST_FILE" ; then
            logInfo "Target file ${DEST_FILE} already copied. Skipping."
            return 0
        fi

        logInfo "Checksum differs, trying another file name..."

        DEST_FILE="${DEST_DIR}/${FILE_PFX}_${idx}.${FILE_EXT}"
        ((idx = idx + 1))
    done

    logError "Could not copy file... Too many tries."
    return 1
}

checkThatWeHave() {
    PROG=$1
    logInfo "Testing if ${PROG} executable exists..."
    if [ -x "$(command -v ${PROG})" ]; then
        logInfo "\e[1;32mOK:\e[0m ${PROG} executable found"
    else
        logError "\e[1;31mError:\e[0m ${PROG} is not installed. Aborting."
        exit 1
    fi
}

DRY_RUN=false
OPERATION="copy"
DEBUG=false
INPUT_DIR=
OUTPUT_DIR=

usage() {
    echo ""
    echo "Usage: ${0} [OPTIONS]"
    echo ""
    echo "OPTIONS"
    echo ""
    echo -e "\t-h               Shows this usage"
    echo -e "\t-in DIR          Specifies the input directory [required]"
    echo -e "\t-out DIR         Specifies the output directory [required]."
    echo -e "\t                 NOTE: the output directory must not"
    echo -e "\t                 be a sub-dir of the input directory."
    echo -e "\t-d               Enables verbose output"
    echo -e "\t-x OPERATION     Defines what file operation to use (copy or move). Default is copy."
    echo -e "\t-dr              Dry run mode. No changes will be done, operation is only logged." 
    echo ""
}

while [ "$1" != "" ]; do
    case $1 in
        -h | --help)
            usage
            exit
            ;;
        -d | --debug)
            DEBUG=true
            ;;
        -in | --input-dir)
            INPUT_DIR=$2
            shift
            ;;
        -out | --output-dir)
            OUTPUT_DIR=$2
            shift
            ;;
        -dr)
            DRY_RUN=true
            ;;
        -x)
            case $2 in
                copy | cp)
                    OPERATION=copy
                    ;;
                move | mv)
                    OPERATION=move
                    ;;
                *)
                    echo "invalid operation: $2"
                    usage
                    exit 1
            esac
            shift
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

if [ -z "${INPUT_DIR}" ]; then
    echo "ERROR: No input directory specified"
    usage
    exit
fi
if [ -z "${OUTPUT_DIR}" ]; then
    echo "ERROR: No output directory specified"
    usage
    exit
fi
if [ ! -d "${INPUT_DIR}" ]; then
    echo "ERROR: Input dir '${INPUT_DIR}' does not exist"
    exit
fi
if [ -f "${OUTPUT_DIR}" ]; then
    echo "ERROR: Output dir '${OUTPUT_DIR}' is a file"
    exit
fi


logInfo "Starting..."
logInfo "    Input Dir      : ${INPUT_DIR}"
logInfo "    Output Dir     : ${OUTPUT_DIR}"
logInfo "    File operation : ${OPERATION}"
if ${DRY_RUN} ; then
    logWarn "**** DRY RUN (NO FILES WILL BE MOVED / COPIED) ****"
fi

# verify tools: exiftool, md5sum, awk, sed, sort, grep, cut, head etc
checkThatWeHave "exiftool"
checkThatWeHave "md5sum"

logInfo "About to find files from ${INPUT_DIR}"

# Find files to be processed...
while read -d '' filename; do
  processFile "${filename}" < /dev/null
done < <(find ${INPUT_DIR} -type f -not -path "*/@eaDir/*" -print0)

logInfo "Done."
