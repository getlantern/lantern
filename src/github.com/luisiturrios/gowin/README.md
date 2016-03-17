gowin
=====

Provide simple Windows OS interface to manipulate windows registry, environment variables, default paths and windows services from Golang lenguaje

###How to use it
```
	go get github.com/luisiturrios/gowin
```

```
	import "github.com/luisiturrios/gowin"
```


###Example write, read, remove windows registry key
```
    //	Write string on the registry require admin privileges
	err = gowin.WriteStringReg("HKLM",`Software\iturrios\gowin`,"value","Hello world")
	if err != nil {
		log.Println(err)
	}else{
		fmt.Println("Key inserted")
	}
```
```
	//	write uint32 on the registry require admin privileges
	err = gowin.WriteDwordReg("HKLM",`Software\iturrios\gowin`,"value2", 4294967295)
	if err != nil {
		log.Println(err)
	}else{
		fmt.Println("Key inserted")
	}
```
```
	//get reg
	val, err := gowin.GetReg("HKLM", `Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders`, "Common AppData")
	if err != nil {
		log.Println(err)
	}
	fmt.Printf(val)
```
```
    // remove key
	err = gowin.DeleteKey("HKLM",`Software\iturrios`,"gowin")
	if err != nil {
		log.Println(err)
	}else{
		fmt.Println("Key Removed")
	}


```
###Example Read windows ShellFolders
```
	folders := gowin.ShellFolders{gowin.ALL}
	//	Or 
	folder := new(gowin.ShellFolders)

	//Read ProgramFiles
	fmt.Println(folders.ProgramFiles())
	
	//Read all user AppData
	folders.Context = gowin.ALL
	fmt.Println(folders.AppData())
	
	//Read Current user AppData
	folders.Context = gowin.USER
	fmt.Println(folders.AppData())

	// functions
	folders.ProgramFiles()
	folders.AppData()
	folders.Desktop()
	folders.Documents()
	folders.StartMenu()
	folders.StartMenuPrograms()
```

###Example Read windows environment variables

```
    // Get environment var
	goroot := gowin.GetEnvVar("GOROOT")
	fmt.Printf("GORROT: %s\n", goroot)
```
```
	// Write environment var
	err := gowin.WriteEnvVar("TVAR","hello word")
	if err != nil {
		log.Println(err)
	}
```


###Donation

If you appreciate the work in this repo and like the continue development donate to this paypal account 
luisiturrios@me.com
Thanks
