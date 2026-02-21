#import "lib.typ": *

#kt-note("cycle-b.typ", depth => [
Cycle-B body.
#transclude("cycle-a.typ", depth: depth)
])
