#!/usr/bin/env bash
./remoteScript.bash localize.bash
scp -i ~/.ec2/id_rsa-gsg-keypair root@issues.littleshoot.org:/home/lantern/lantern/src/main/resources/*.class ../src/main/resources
