#import "lib.typ": *

#kt-note("cycle-a.typ", depth => [
Cycle-A body.
#transclude("cycle-b.typ", depth: depth)
])
