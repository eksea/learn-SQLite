#!/bin/bash
#
# Run this script to push a build of the SQLite website (found in
# ~/sqlite/website/bld/doc) up to all three servers.
#
export RSYNC_RSH=ssh
cd ~/sqlite/website/bld/doc
if grep DRAFT index.html >/dev/null
then 
  DEST=/draft
else
  DEST=
fi
rm -rf matrix
echo 'www.sqlite.org:'
rsync -r * root@sqlite.org:/home/www/www_sqlite_org.website$DEST
echo 'www2.sqlite.org:'
rsync -r * root@www2.sqlite.org:/home/www/www_sqlite_org.website$DEST
echo 'www3.sqlite.org:'
rsync -r * hwaci@sugar.he.net:public_html/sw/sqlite$DEST
