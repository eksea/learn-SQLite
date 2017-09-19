#!/bin/sh
#
# Usage:
#
#      sh remove_carets.sh doc
#
# This script scans all *.html file in subdirectory "doc" and remove
# certain character sequences from those files.  Character sequences
# removed are:
#
#     ^(
#     )^
#     ^
#
echo 'Removing ^ characters '
find $1 -name '*.html' -print | grep -v matrix | while read file
do
  mv "$file" x.html
  sed -e 's/\^(//g' -e 's/)^//g' -e 's/\^//g' x.html >"$file"
done
