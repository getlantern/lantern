#!/usr/bin/env bash
./remoteScript.bash localize.bash
scp -i ~/.ec2/id_rsa-gsg-keypair root@issues.littleshoot.org:/home/lantern/lantern/src/main/resources/app/i18n/*.class ../src/main/resources/app/i18n/
scp -i ~/.ec2/id_rsa-gsg-keypair root@issues.littleshoot.org:/home/lantern/lantern/po/*.po ../po/
scp -i ~/.ec2/id_rsa-gsg-keypair root@issues.littleshoot.org:/home/lantern/lantern/po/keys.pot ../po/
