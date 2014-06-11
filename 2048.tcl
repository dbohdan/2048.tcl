# A minimal implementation of the game 2048 in Tcl.
package require Tcl 8.5
package require struct::matrix
package require struct::list

# Board size.
set size 4

# Iterate over all cells of the game board and run script for each.
#
# We imagine the game board to consist of cells that each can contain a game
# tile that corresponds to numbers 2..2048 or nothing.
# - cellList is a list of cell indexes (coordinates), which are
# themselves lists of the form {i j} that each represent the location
# of a cell on the board.
# - varName1 are varName2 are names of index variables
# - cellVarName is names of variables that will contain the values of the cell
# for each cell. Assigning to it will change the game board.
# - script is the script to run
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

# Generate a list of cell indexes for all cells on the board.
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

# Return 1 if the predicate pred is true when applied to all item on the list
# or 0 otherwise.
proc map-and {list pred} {
    set res 1
    foreach item $list {
        set res [expr {$res && [$pred $item]}]
        if {! $res} break
    }
    return $res
}

# Say if list represents valid cell coordinates.
proc valid-cell? cell {
    map-and $cell valid-index
}

# Get value of game board cell.
proc cell-get cell {
    board get cell {*}$cell
}

# Set value of game board cell.
proc cell-set {cell value} {
    board set cell {*}$cell $value
}

# Filter a list of board cell indexes cellList to only leave in those indexes
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

# Vector sum of lists v1 and v2.
proc vector-add {v1 v2} {
    set result {}
    foreach a $v1 b $v2 {
        lappend result [expr {$a + $b}]
    }
    return $result
}

# Try to shift all cells one step in the direction of directionVect
# or just say if that move is possible.
proc move-all {directionVect {checkOnly 0}} {
    set changedCells 0

    forcells [cell-indexes] i j cell {
        set newIndex [vector-add "$i $j" $directionVect]
        set removedStar 0

        if {$cell eq {2*}} {
            set cell 2
            set removedStar 1
        }

        # For every nonempty source cell and valid destination cell...
        if {$cell != 0 && [valid-cell? $newIndex]} {
            # Destination is empty.
            if {[cell-get $newIndex] == 0} {
                if {$checkOnly} {
                    # -level 2 is to return from both forcells and move-all.
                    return -level 2 true
                } else {
                    # Move tile to empty cell.
                    cell-set $newIndex $cell
                    set cell 0
                    incr changedCells
                }
            # Destination is the same number as source.
            } elseif {([cell-get $newIndex] eq $cell) &&
                      [string first + $cell] == -1} {
                if {$checkOnly} {
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

        if {$checkOnly && $removedStar} {
            set cell {2*}
        }
    }

    if {$checkOnly} {
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

# Pretty-print the board.
proc print-board {} {
    forcells [cell-indexes] i j cell {
        if {$j == 0} {
            puts ""
        }
        puts -nonewline [
            if {$cell != 0} {
                format "\[%4s\]" $cell
            } else {
                lindex "......"
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

    # Generate emply board of the given size.
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

        # Find possible moves.
        foreach {button vector} $controls {
            dict set canMove $button [can-move? $vector]
        }
        check-lose $canMove

        # Get valid input from the player.
        while {$playerMove == 0} {
            # Print prompt.
            puts -nonewline "Move ("
            foreach {button vector} $controls {
                if {[dict get $canMove $button]} {
                    puts -nonewline $button
                }
            }
            puts ")?"

            set playerInput [gets stdin]

            # Validate input.
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