package igdman

import (
	"fmt"
	"log"
	"os/exec"
	"regexp"
	"time"
)

var (
	searchRegex *regexp.Regexp
)

func init() {
	var err error
	searchRegex, err = regexp.Compile("default via ([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9,]{1,3}\\.[0-9,]{1,3})\\.*")
	if err != nil {
		log.Fatalf("Unable to compile searchRegex: %s", err)
	}
}

func defaultGatewayIp() (string, error) {
	cmd := exec.Command("ip", "route", "ls")
	out, err := execTimeout(10*time.Second, cmd)
	if err != nil {
		return "", fmt.Errorf("Unable to call ip: %s\n%s", err, out)
	}

	submatches := searchRegex.FindSubmatch(out)
	if len(submatches) < 2 {
		return "", fmt.Errorf("Unable to find default gateway in ip output: \n%s", out)
	}

	return string(submatches[1]), nil
}
