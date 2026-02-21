#import "lib.typ": *

// Register all notes
#include "cycle-a.typ"
#include "cycle-b.typ"

// Transclude from registry
Root (cycle test):
#transclude("cycle-a.typ")
