#import "lib.typ": *

#kt-note("bar.typ", depth => [
Bar body.
#transclude("baz.typ", depth: depth)
])
