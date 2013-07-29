#!/usr/bin/python

files = [
    ["../install/java6/local_policy.jar",
     "../install/java6/US_export_policy.jar"],
    ["../install/java7/local_policy.jar",
     "../install/java7/US_export_policy.jar"]
]

out = "int POLICY_JAR_LEN [%d][%d] = {" % (len(files) + 1, len(files[0]))
for version in files:
    for file in version:
        f = open(file)
        data = f.read()
        out += "%d," % len(data)
        f.close()

out += "0};\n"

out += "const char* POLICY_JAR_CONTENTS [%d][%d] = {" % (len(files) + 1, len(files[0]))

for version in files:
    for file in version:
        out += "\""
        f = open(file)
        data = f.read()
        out += "".join("\\x%x" % ord(c) for c in data)
        out += "\",\n"

out += "0};"

f = open("policy_jars.h", "wb")
print >>f, out
f.close()

