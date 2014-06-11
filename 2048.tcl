# A minimal implementation of the game 2048 in Tcl.
package require Tcl 8.5
package require struct::matrix
package require struct::list

# Board size.
set size 4

# Vector sum of lists v1 and v2.
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

proc map-and {list pred} {
	set res 1
	foreach item $list {
		set res [expr {$res && [$pred $item]}]
		if {! $res} break
	}
	return $res
}

proc valid-indexes list {
	map-and $list valid-index
}

proc cell-get cell {
	board get cell {*}$cell
}

proc cell-set {cell value} {
	board set cell {*}$cell $value
}

# Filter the list of board cell indexes cellList to only leave in those indexes
# that correspond to empty board cells.
proc empty {cellList} {
	::struct::list filterfor x $cellList {[cell-get $x] == 0}
}

# Pick a random item from list.
proc pick list {
	lindex $list [expr {int(rand() * [llength $list])}]
}

# Put a "2" into an empty cell on the board.
proc spawn-new {} {
	set emptyCell [pick [empty [cell-indexes]]]
	if {[llength $emptyCell] > 0} {
		forcells [list $emptyCell] i j cell {
			set cell 2*
		}
	}
}

# Try to shift all cells one step in the direction of directionVect.
proc move-all {directionVect {onlyCheck 0}} {
	set changedCells 0
	forcells [cell-indexes] i j cell {
		set newIndex [vector-add "$i $j" $directionVect]
		set removedStar 0
		if {$cell eq {2*}} {
			set cell 2
			set removedStar 1
		}
		if {$cell != 0 && [valid-indexes $newIndex]} {
			if {[cell-get $newIndex] == 0} {
				if {$onlyCheck} {
					return -level 2 true
				} else {
					cell-set $newIndex $cell
					set cell 0
					incr changedCells
				}
			} elseif {([cell-get $newIndex] eq $cell) &&
				      [string first + $cell] == -1} {
				if {$onlyCheck} {
					return -level 2 true
				} else {
					# When merging two tiles into one mark the new tile with
					# the marker of "+" to ensure it doesn't get merged
					# again this turn.
					cell-set $newIndex [expr {2 * $cell}]+
					set cell 0
					incr changedCells
				}
			}
		}
		if {$onlyCheck && $removedStar} {
			set cell {2*}
		}
	}
	if {$onlyCheck} {
		return false
	}
	# Remove "changed this turn" markers at the end of the turn.
	if {$changedCells == 0} {
		forcells [cell-indexes] i j cell {
			set cell [string trim $cell +]
		}
	}
	return $changedCells
}

# Is it possible to move any tiles in the direction of directionVect?
proc can-move? {directionVect} {
	move-all $directionVect 1
}

# The player wins when there's a 2048 tile.
proc check-win {} {
	forcells [cell-indexes] i j cell {
		if {$cell == 2048} {
			puts "You win!"
			exit 0
		}
	}
}

# The player loses when the win condition isn't met and there are no possible
# moves left.
proc check-lose {canMove} {
	set values [dict values $canMove]
	if {!(true in $values || 1 in $values)} {
		puts "You lose."
		exit 0
	}
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

	set controls {
		h {0 -1}
		j {1 0}
		k {-1 0}
		l {0 1}
	}

	# Game loop.
	while true {
		set playerMove 0
		set canMove {}
		spawn-new
		print-board
		check-win
		foreach {button vector} $controls {
			dict set canMove $button [can-move? $vector]
		}
		check-lose $canMove
		while {$playerMove == 0} {
			puts -nonewline "Move ("
			foreach {button vector} $controls {
				if {[dict get $canMove $button]} {
					puts -nonewline $button
				}
			}
			puts ")?"
			set playerInput [gets stdin]
			if {[dict exists $canMove $playerInput] &&
				[dict get $canMove $playerInput] &&
				[dict exists $controls $playerInput]} {
				set playerMove [dict get $controls $playerInput]
			}
		}
		# Apply current move while changes occur on the board.
		while true {
			if {[move-all $playerMove] == 0} break
		}
	}
}

main