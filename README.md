# Photo Arranger

This simple Bash script assist in arranging photos and movies by its creation date.
Often the photos are just put into some folder when backing up the phone etc, and its difficult to arrange these later.

This script will use the Exiftool to extract meta data from the photos then
rearrange the files based upon year and month when the photo was taken.

You can chose to copy or move the files from the input dir to the output dir,
amd you can run this script incrementally since the script will compare already existing files
using a MD5 hash.

## Basic Usage

Usage: 

    ./photo-arranger.sh [OPTIONS]

OPTIONS

	-h               Shows this usage
	-in DIR          Specifies the input directory [required]
	-out DIR         Specifies the output directory [required].
	                 NOTE: the output directory must not
	                 be a sub-dir of the input directory.
	-d               Enables verbose output
	-x OPERATION     Defines what file operation to use (copy or move). Default is copy.
	-dr              Dry run mode. No changes will be done, operation is only logged.
    -l LOGFILE       Append log to LOGFILE


Example:

    ./photo-arranger.sh -in /mnt/photos -out /home/3rrki/photos -d

## Required Tools

You need at least

* exiftool
* md5sum
* decent version of Bash

