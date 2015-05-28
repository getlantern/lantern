// Test of detached package comment.

/*
Package foo is pretty sweet.
*/

package foo

// MATCH:6 /package comment.*detached/
