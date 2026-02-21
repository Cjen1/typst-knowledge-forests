#import "lib.typ": *

#kt-note("cycle-b.typ", transclude => [
Cycle-B body.
#transclude("cycle-a.typ")
])
