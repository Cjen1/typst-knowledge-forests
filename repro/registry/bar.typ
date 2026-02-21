#import "lib.typ": *

#kt-note("bar.typ", transclude => [
Bar body.
#transclude("baz.typ")
])
