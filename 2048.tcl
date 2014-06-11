# A minimal implementation of the game 2048 in Tcl
package require Tcl 8.2
package require struct::matrix
package require struct::list

# Board size.
set size 4

proc vector-add {v1 v2} {
	set result {}
	foreach a $v1 b $v2 {
		lappend result [expr {$a + $b}]
	}
	return $result
}

# Iterate over all cells of the game board.
proc forcells {cellList varName1 varName2 cellVarName script} {
	upvar $varName1 i
	upvar $varName2 j
	upvar $cellVarName c
	foreach cell $cellList {
		set i [lindex $cell 0]
		set j [lindex $cell 1]
		set c [cell-get $cell]
		uplevel $script
		cell-set "$i $j" $c
	}
}

# Generate a list of index vectors (lists of the form {i j}) of all cells of
# the board.
proc cell-indexes {} {
	global size
	set list {}
	foreach i [::struct::list iota $size] {
		foreach j [::struct::list iota $size] {
			lappend list [list $i $j]
		}
	}
	return $list
}

proc valid-index {i} {
	global size
	expr {0 <= $i && $i < $size}
}

proc map-and {vect pred} {
	set res 1
	foreach item $vect {
		set res [expr {$res && [$pred $item]}]
		if {! $res} break
	}
	return $res
}

proc valid-indexes vect {
	map-and $vect valid-index
}

# Get the list of game board cells adjacent to coordinates $vect.
proc adjacent {vect} {
	set adjacentList {}
	foreach offset {{-1 0} {1 0} {0 -1} {0 1}} {
		lappend adjacentList [vector-add $vect $offset]
	}
	return [::struct::list filter $adjacentList valid-indexes]
}

proc cell-get cell {
	board get cell {*}$cell
}

proc cell-set {cell value} {
	board set cell {*}$cell $value
}

proc uniq {list} {
    lsort -unique $list
}

# Filter the list of board cell indexes $cellList to only leave those indexes
# that correspond to empty cells.
proc empty {cellList} {
	::struct::list filterfor x $cellList {[cell-get $x] == 0}
}

# Filter the list of board cell indexes $cellList to only leave those indexes
# that correspond to non-empty cells.
proc nonempty {cellList} {
	::struct::list filterfor x $cellList {[cell-get $x] != 0}
}

# Filter the list of board cell indexes $cellList to only leave those indexes
# that correspont to cells next to nonempty cells.
proc adjacent-to-nonempty {cellList} {
	uniq [::struct::list flatten [::struct::list map [nonempty $cellList] adjacent]]
}

# Pick a randon item from $list.
proc pick list {
	lindex $list [expr {int(rand() * [llength $list])}]
}

# Add a "1" to an empty cell on the board adjacent to an nonempty one.
proc spawn-one {} {
	forcells [list [pick [empty [adjacent-to-nonempty [cell-indexes]]]]] i j cell {
		set cell 1*
	}
}

# Try to shift all cells one step in the direction of $directionVect.
proc move-all {directionVect} {
	set changedCells 0
	forcells [cell-indexes] i j cell {
		set newIndex [vector-add "$i $j" $directionVect]
		if {$cell eq {1*}} {
			set cell 1
		}
		if {$cell != 0 && [valid-indexes $newIndex]} {
			if {[cell-get $newIndex] == 0} {
				cell-set $newIndex $cell
				set cell 0
				incr changedCells
			} elseif {[cell-get $newIndex] == $cell} {
				cell-set $newIndex [expr {2 * $cell}]
				set cell 0
				incr changedCells
			}
		}
	}
	return $changedCells
}

proc main {} {
	global size

	struct::matrix board
	board add columns $size
	board add rows $size

	# Generate starting board
	forcells [cell-indexes] i j cell {
		set cell 0
	}
	forcells [list [pick [cell-indexes]]] i j cell {
		set cell 1
	}

	# Game loop.
	while true {
		set playerMove 0
		puts [board format 2string]
		puts "----"
		while {$playerMove == 0} {
			set playerMove [
				switch [gets stdin] {
					h {lindex {-1  0}}
					j {lindex { 0  1}}
					k {lindex { 0 -1}}
					l {lindex { 1  0}}
					default {lindex 0}
				}
			]
		}
		while true {
			if {[move-all $playerMove] == 0} break
		}
		spawn-one
	}
}

main