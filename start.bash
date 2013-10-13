#!/bin/bash

nohup ./run.bash --disable-ui --oauth2-client-secrets-file=src/main/resources/client_secrets_installed.json --oauth2-user-credentials-file=credentials.json $* &
