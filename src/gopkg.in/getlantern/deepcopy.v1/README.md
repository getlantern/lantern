deepcopy provides a basic implementation of deep copying using json.Marshal
and json.Unmarshal.  Hence it is not very performant, and it only works for
exported fields.

See [gopkg.in](http://gopkg.in/getlantern/deepcopy.v1) for usage and docs.