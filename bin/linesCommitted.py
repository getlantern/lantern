#!/usr/bin/env python

import commands
import os
import sys

if (len(sys.argv) != 3):
    print "Usage: ./linesCommitted.py 2011-10-01 2012-01-01"
    sys.exit(1)

start = sys.argv[1]
end = sys.argv[2]

hist = commands.getoutput("git log --shortstat --reverse --pretty=oneline --after=\""+start+"\" --before=\""+end+"\" --no-merges ../src/")
hist = hist.split("\n")
totalins = 0

for line in hist:
    if line.startswith(' '):
        ins =  line.split(",")[1]
        totalins = totalins + int(ins.split(" ")[1])

print "Between " + start + " and " + end + " the Lantern team wrote " + str(totalins) + " lines of code!"
