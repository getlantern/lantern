# go-update: Automatically update Go programs from the internet

go-update allows programs to self-update from an update file or URL on the internet.

    err, errRecover := update.SelfFromUrl("https://release.example.com/2.0/myprogram")
    if err != nil {
        fmt.Printf("Update failed: %v", err)
    }

You can even update from binary patches:

    err, errRecover := update.SelfFromPatchUrl("https://release.example.com/2.0/myprogram/patch/1.0")
    if err != nil {
        fmt.Printf("Update failed: %v", err)
    }

go-update addionally includes a Download utility which allows you to monitor the progress percentage
of a large download.

Lastly, go-update implements a separate protocol 
