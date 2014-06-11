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

proc cell-get cell {
	board get cell {*}$cell
}

proc cell-set {cell value} {
	board set cell {*}$cell $value
}

# Filter the list of board cell indexes $cellList to only leave those indexes
# that correspond to empty cells.
proc empty {cellList} {
	::struct::list filterfor x $cellList {[cell-get $x] == 0}
}

# Pick a randon item from $list.
proc pick list {
	lindex $list [expr {int(rand() * [llength $list])}]
}

# Put a "2" into an empty cell on the board.
proc spawn-new {} {
	forcells [list [pick [empty [cell-indexes]]]] i j cell {
		set cell 2*
	}
}

# Try to shift all cells one step in the direction of $directionVect.
proc move-all {directionVect} {
	set changedCells 0
	forcells [cell-indexes] i j cell {
		set newIndex [vector-add "$i $j" $directionVect]
		if {$cell eq {2*}} {
			set cell 2
		}
		if {$cell != 0 && [valid-indexes $newIndex]} {
			if {[cell-get $newIndex] == 0} {
				cell-set $newIndex $cell
				set cell 0
				incr changedCells
			} elseif {[cell-get $newIndex] eq $cell} {
				# When merging two cells into one mark the new cell with a
				# marker of "+" to ensure it doesn't get merged or moved
				# again this turn.
				cell-set $newIndex [expr {2 * $cell}]+
				set cell 0
				incr changedCells
			}
		}
	}
	# Remove "changed this turn" markers at the end of the turn.
	if {$changedCells == 0} {
		forcells [cell-indexes] i j cell {
			set cell [string trim $cell +]
		}
	}
	return $changedCells
}

proc print-board {} {
	forcells [cell-indexes] i j cell {
		if {$j == 0} {
			puts ""
		}
		puts -nonewline [
			if {$cell != 0} {
				format "\[%3s\]" $cell
			} else {
				lindex "....."
			}
		]
	}
	puts "\n"
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

	# Game loop.
	while true {
		set playerMove 0
		spawn-new
		print-board
		while {$playerMove == 0} {
			puts "Move (h, j, k, l)?"
			set playerMove [
				switch [gets stdin] {
					h {lindex {0 -1}}
					j {lindex {1 0}}
					k {lindex {-1 0}}
					l {lindex {0 1}}
					default {lindex 0}
				}
			]
		}
		while true {
			if {[move-all $playerMove] == 0} break
		}
	}
}

main