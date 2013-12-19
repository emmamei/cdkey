#!/bin/bash

cd ./preprocessor

if [ $? -ne 0 ]; then
   echo "${0}: Error 2: Unable to cd to ./preprocessor" >&2
   exit 2
fi

for FILE in `ls -1 *.lslp`; do
   OUTPUT=`echo ${FILE} | grep -Po '^[[:alnum:]]*'`.lsl
   cpp -C ${FILE} | sed -e 's/^#/\/\//' >"../${OUTPUT}"
done
