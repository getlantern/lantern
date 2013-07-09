#!/usr/bin/python

files = ["../install/java7/local_policy.jar",
 "../install/java7/US_export_policy.jar"]

out = "int POLICY_JAR_LEN [] = {"
for file in files:
    f = open(file)
    data = f.read()
    out += "%d," % len(data)
    f.close()

out += "0};\n"

out += "const char* POLICY_JAR_CONTENTS [] = {"

for file in files:
    out += "\""
    f = open(file)
    data = f.read()
    out += "".join("\\x%x" % ord(c) for c in data)
    out += "\",\n"

out += "0};"

f = open("policy_jars.h", "wb")
print >>f, out
f.close()

