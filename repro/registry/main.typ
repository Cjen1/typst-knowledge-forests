#import "lib.typ": *

// Register all notes (each #include triggers kt-note which registers content)
#include "foo.typ"
#include "bar.typ"
#include "baz.typ"

// Now transclude from the registry
Root:
#transclude("foo.typ")
