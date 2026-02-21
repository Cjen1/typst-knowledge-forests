#import "lib.typ": *

#kt-note("foo.typ", depth => [
Foo body.
#transclude("bar.typ", depth: depth)
])
