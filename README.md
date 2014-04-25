# go-update: Automatically update Go programs from the internet

go-update allows programs to update themselves from the internet, replacing their executable file with a new binary. go-update allows Go application developers to create user experiences which require no user interaction to update to new versions.

## Example simple update
Updating your program to a new version is as easy as:

	err, errRecover := update.New().FromUrl("http://release.example.com/2.0/myprogram")
	if err != nil {
		fmt.Printf("Update failed: %v\n", err)
	}

## Important Features

- Binary diff application
- Checksum verification
- Authenticity verification via code signing
- Separate, simple JSON protocol for determining update availability

## Documentation and API Reference
It's available on godoc: [https://godoc.org/github.com/inconshreveable/go-update](https://godoc.org/github.com/inconshreveable/go-update)


## equinox.io
go-update is the open-source component of the more complete updating solution that I provide at [equinox.io](https://equinox.io)
