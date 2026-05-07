#!/bin/bash
set -e

if [ "$1" = 'minion' ]; then
    exec carton exec ./edu_maps.pl minion worker
else
    exec carton exec morbo edu_maps.pl
fi
