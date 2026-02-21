#import "lib.typ": *

#kt-note("cycle-a.typ", transclude => [
Cycle-A body.
#transclude("cycle-b.typ")
])
