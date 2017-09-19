#!/bin/sh
#
# Usage:
#
#      sh spell_chk.sh doc '*.html' ./custom.txt
#      sh spell_chk.sh pages '*.in'
#      sh spell_chk.sh ../sqlite/src '*.c'
#
# This script scans all "*.html" file in subdirectory "doc" and reports
# spelling mistakes.
#
# Custom words (words to ignore) are stored in custom.txt.
#
if [ $# -ge 3 ] && [ -f $3 ]
then
  echo 'Updating custom dictionary '
  aspell --lang=en create master ./custom.rws < $3
fi
#
echo "Spell checking $1/$2..."
find $1 -name "$2" -print | grep -v matrix | while read file
do
  # echo "Checking $file..."
  # determine spell check mode based on file extension
  mode=${file##*\.}
  if [ "$mode" = "html" ]; then mode="html"
  elif [ "$mode" = "c" ]; then mode="ccpp"
  elif [ "$mode" = "h" ]; then mode="ccpp"
  elif [ "$mode" = "test" ]; then mode="comment"
  elif [ "$mode" = "tcl" ]; then mode="comment"
  elif [ "$mode" = "pl" ]; then mode="perl"; fi
  # aspell's "list" option just lists all the misspelled words w/o any context.
  # we pass this list to grep to get line numbers.
  aspell --extra-dicts ./custom.rws --mode=$mode list < $file | sort | uniq | while read word
  do
    grep -H -n -o -P "\b$word\b" $file
  done

  # check some commonly "doubled" words 
  # http://en.wikipedia.org/wiki/Wikipedia:Lists_of_common_misspellings/Repetitions
  for word in the it that you is a in to had use an or and at
  do
    # echo "$file -> [$word]"
    grep -H -n -o -i -P "\b$word\s+$word\b" $file
  done

  # "a" or "an" (filter some common exceptions)
  grep -H -n -o -P "\b[Aa]\s+[aeiou]\w+" $file | grep -v -i -P "(one|user|uniq|unary|union|hist)"
  grep -H -n -o -P "\b[Aa]n\s+[bcdfghjklmnpqrstvwxyz]\w+" $file | grep -v -i -P "(sqlite|honor|honest|x86)"
  # for abbreviations/acronyms (if first two letters caps)
  # vowel-sounding letters (take "an"):  A E F H I L M N O S X
  grep -H -n -o -P "\b[Aa]\s+[AEFHILMNOSX][A-Z]\w*" $file | grep -v -P "(FROM|HAVING|HIDDEN|LEFT|LIKE|LIMIT|MATCH|NEAR|NULL|SAVEPOINT|SELECT|SHARED)"
  # consonant-sounding letters (take "a"):  B C D G J K P Q R T U V W Y Z
  grep -H -n -o -P "\b[Aa]n\s+[BCDGJKPQRTUVWYZ][A-Z]\w*" $file | grep -v -P "(UPDATE)"
done
echo "Spell checking $1/$2... done."
