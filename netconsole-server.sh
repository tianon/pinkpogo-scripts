#!/bin/bash
set -e

set -x
reset
exec nc -l -u -p 6666
