#import "lib.typ": *

#kt-note("foo.typ", transclude => [
Foo body.
#transclude("bar.typ")
])
