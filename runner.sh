#!/bin/sh
set -e

echo "Starting script.pl..."
/usr/bin/env perl /app/script.pl
rc=$?
if [ $rc -ne 0 ]; then
  echo "script.pl failed with exit code $rc"
  exit $rc
fi

echo "script.pl finished successfully — starting web.pl (HTTP server)..."

exec /usr/bin/env perl /app/web.pl
