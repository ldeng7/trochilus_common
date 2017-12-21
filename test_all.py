#!/usr/bin/python
# add environment variable "OPRPATH" of lua code base path, such as:
# export OPRPATH="/home/me/work/opr"
# add environment variable "OPRROOT" of openresty installation path , such as:
# export OPRROOT="/home/me/bin/opr"

import os, sys, commands

if sys.argv[0] not in ["test_all.py", "./test_all.py"]:
    print "run in src root path only!"
    sys.exit(1)
OPRPATH = os.environ["OPRPATH"]
OPRROOT = os.environ["OPRROOT"]
args = sys.argv[:]
args[0] = ""

for p, _, fs in os.walk(os.path.join(os.getcwd(), "test")):
    for testFile in [os.path.join(p, f) for f in fs if f.startswith("test_") and f.endswith(".lua")]:
        print "\n=== " + testFile
        out = commands.getoutput(OPRROOT + "/luajit/bin/luajit " + testFile + " ".join(args)).split("\n")
        if "OK" == out[-1]:
            print "\033[0;32mPASS\033[0m"
        else:
            print "\033[0;31mFAIL\033[0m"
            print "\n".join(out)
            sys.exit(1)
