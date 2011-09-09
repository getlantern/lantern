#!/usr/bin/env bash
ssh -i ~/.ec2/id_rsa-gsg-keypair root@issues.littleshoot.org "bash -s" < $1
