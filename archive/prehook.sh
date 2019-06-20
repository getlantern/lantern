#!/bin/sh

# Shared pre push/commit hook for the Lantern project
# Maintainer: Ulysses Aalto <uaalto@getlantern.org>
#
# Installation: Symlink or copy into .git/hooks/prehook.sh

echo "Running hook -- Analyzing modified packages..."
FOUND_CHANGE=false
for i in $MODIFIED_DIRS; do
    echo " * $i";
    FOUND_CHANGE=true;
done

if [ "$FOUND_CHANGE" = false ]; then
    echo "No changes to analyze";
    exit 0;
fi

cd src/github.com/getlantern

which errcheck >/dev/null || (echo "Unable to find errcheck, please install it: \`go get github.com/kisielk/errcheck\`" && exit 1)
which golint >/dev/null || (echo "Unable to find golint, please install it: \`go get -u github.com/golang/lint/golint\`" && exit 1)

echo "*** Running \033[0;34mErrcheck\033[0m ***" && \
for dir in $MODIFIED_DIRS; do
  errcheck github.com/getlantern/$dir || (\
    echo "\033[0;31merrcheck returned error analyzing the package '$dir'\033[0m" && \
    echo "Please, fix and run again\n" && \
    exit 1)
done
echo "\033[1;34mErrcheck\033[0m ran successfully\n"

echo "*** Running \033[0;34mGo vet\033[0m ***" && \
for dir in $MODIFIED_DIRS; do
  go vet github.com/getlantern/$dir || (\
    echo "\033[0;31mgo vet returned error analyzing the package '$dir'\033[0m"
    echo "Please, fix and run again\n" && \
    exit 1)
done
echo "\033[1;34mGo vet\033[0m ran successfully\n"

echo "*** Running \033[0;34mGolint\033[0m ***" && \
for dir in $MODIFIED_DIRS; do
  golint github.com/getlantern/$dir || (\
    echo "\033[0;31mgo vet returned error analyzing the package '$dir'\033[0m"
    echo "Please, fix and run again\n" && \
    exit 1)
done
echo "\033[1;34mGolint\033[0m ran successfully\n"

echo "*** Running \033[0;34mGo test -race\033[0m ***" && \
for dir in $MODIFIED_DIRS; do
  go test -race github.com/getlantern/$dir || (\
    echo "\033[0;31mgo vet returned error analyzing the package '$dir'\033[0m"
    echo "Please, fix and run again\n" && \
    exit 1)
done
echo "\033[1;34mGo test -race\033[0m ran successfully\n"
