#!/bin/bash

PATH_ARCHIVE_XLOGS=$1
FILE=$2
WAL_SEGMENT=$3

if [ ! -z $PATH_ARCHIVE_XLOGS ];
then
    test ! -f ${PATH_ARCHIVE_XLOGS}/${FILE} && cp $WAL_SEGMENT ${PATH_ARCHIVE_XLOGS}/${FILE}
    chmod 0644 ${PATH_ARCHIVE_XLOGS}/${FILE}
    find ${PATH_ARCHIVE_XLOGS} -type f -mtime +7 -delete
else
    echo "WARNING: PATH_ARCHIVE_XLOGS is not defined"
fi
