for i in $(seq 1 4); do
  sed s/"internalVersion =.*"/"internalVersion = \"v0.$i.0\""/g main.go > main.go.tmp
  mv main.go.tmp main.go
  GOOS=darwin GOARCH=amd64 go build -o autoupdate-binary-darwin-amd64.v$i
  GOOS=linux GOARCH=386 go build -o autoupdate-binary-linux-386.v$i
  GOOS=windows GOARCH=386 go build -o autoupdate-binary-windows-amd64.v$i
done

git checkout main.go
