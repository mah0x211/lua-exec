#!/bin/sh

set -e

sleep 0.1
echo $@ $TEST_ENV
echo "error message" >&2

# if argument is "read_stdin", read stdin and echo it until timeout
if [ "$1" = "read_stdin" ]; then
    while read -t 1 line; do
        echo "$line"
    done
    echo "EOF"
fi
