// package deepcopy provides functionality for making deep copies of objects.
// We originally wanted to use code.google.com/p/rog-go/exp/deepcopy, but it's
// not working with a current version of Go (even after fixing compile issues,
// its unit tests don't pass). Hence, we created this deepcopy.  It makes a
// deep copy by using json.Marshal and json.Unmarshal, so it's not very
// performant.
package deepcopy

import (
	"encoding/json"
	"fmt"
)

// Make a deep copy from src into dst.
func Copy(dst interface{}, src interface{}) error {
	if dst == nil {
		return fmt.Errorf("dst cannot be nil")
	}
	if src == nil {
		return fmt.Errorf("src cannot be nil")
	}
	bytes, err := json.Marshal(src)
	if err != nil {
		return fmt.Errorf("Unable to marshal src: %s", err)
	}
	err = json.Unmarshal(bytes, dst)
	if err != nil {
		return fmt.Errorf("Unable to unmarshal into dst: %s", err)
	}
	return nil
}
