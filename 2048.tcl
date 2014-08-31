#! /bin/env tclsh
# A minimal implementation of the game 2048 in Tcl.
# Version 0.2.4.
# This code is released under the terms of the MIT license. See the file
# LICENSE for details.
# More at:
# - https://github.com/dbohdan/2048-tcl -- Git repository;
# - http://wiki.tcl.tk/39566            -- discussion.

package require Tcl 8.5
package require struct::matrix
package require struct::list

# utilities

proc vars args {
    foreach varname $args {
        uplevel [list variable $varname]
    }
}

# Iterate over all cells of the game board and run script for each.
#
# The game board is a 2D matrix of a fixed size that consists of elements
# called "cells" that each can contain a game tile (corresponds to numerical
# values of 2, 4, 8, ..., 2048) or nothing (zero).
#
# - cellList is a list of cell indexes (coordinates), which are
# themselves lists of two numbers each. They each represent the location
# of a given cell on the board.
# - varName1 are varName2 are names of the variables the will be assigned
# the index values.
# - cellVarName is the name of the variable that at each step of iteration
# will contain the numerical value of the present cell. Assigning to it will
# change the cell's value.
# - script is the script to run.
proc forcells {cellList varName1 varName2 cellVarName script} {
    upvar $varName1 i
    upvar $varName2 j
    upvar $cellVarName c
    foreach cell $cellList {
        set i [lindex $cell 0]
        set j [lindex $cell 1]
        set c [cell-get $cell]
        set status [catch [list uplevel $script] cres copts]
        switch $status {
            2 {
                return -options [dict replace $copts -level 2] $cres
            }
            default {
                return -options $copts $cres
            }
        }
        cell-set [list $i $j] $c
    }
}

# Generate a list of cell indexes for all cells on the board, i.e.,
# {{0 0} {0 1} ... {0 size-1} {1 0} {1 1} ... {size-1 size-1}}.
proc cell-indexes {} {
    variable size
    set list {}
    foreach i [::struct::list iota $size] {
        foreach j [::struct::list iota $size] {
            lappend list [list $i $j]
        }
    }
    return $list
}

# Check if a number is a valid cell index (is 0 to size-1).
proc valid-index i {
    variable size
    expr {0 <= $i && $i < $size}
}

# Return 1 if the predicate pred is true when applied to all items on the list
# or 0 otherwise.
proc map-and {list pred} {
    set res 1
    foreach item $list {
        set res [expr {$res && [$pred $item]}]
        if {! $res} break
    }
    return $res
}

# Check if list represents valid cell coordinates.
proc valid-cell? cell {
    map-and $cell valid-index
}

# Get the value of a game board cell.
proc cell-get cell {
    board get cell {*}$cell
}

# Set the value of a game board cell.
proc cell-set {cell value} {
    board set cell {*}$cell $value
}

# Filter a list of board cell indexes cellList to only have those indexes
# that correspond to empty board cells.
proc empty cellList {
    ::struct::list filterfor x $cellList {[cell-get $x] == 0}
}

# Pick a random item from the given list.
proc pick list {
    lindex $list [expr {int(rand() * [llength $list])}]
}

# Put a "2*" into an empty cell on the board. The star is to indicate it's new
# for the player's convenience.
proc spawn-new {} {
    set emptyCell [pick [empty [cell-indexes]]]
    if {[llength $emptyCell] > 0} {
        forcells [list $emptyCell] i j cell {
            set cell 2
        }
    }
    return $emptyCell
}

# Return vector sum of lists v1 and v2.
proc vector-add {v1 v2} {
    set result {}
    foreach a $v1 b $v2 {
        lappend result [expr {$a + $b}]
    }
    return $result
}

# If checkOnly is false try to shift all cells one step in the direction of
# directionVect. If checkOnly is true just say if that move is possible.
proc move-all {directionVect {checkOnly 0}} {
    set changedCells 0

    forcells [cell-indexes] i j cell {
        set newIndex [vector-add [list $i $j] $directionVect]
        set removedStar 0

        # For every nonempty source cell and valid destination cell...
        if {$cell != 0 && [valid-cell? $newIndex]} {
            if {[cell-get $newIndex] == 0} {
                # Destination is empty.
                if {$checkOnly} {
                    return true
                } else {
                    # Move tile to empty cell.
                    cell-set $newIndex $cell
                    set cell 0
                    incr changedCells
                }
            } elseif {([cell-get $newIndex] eq $cell) &&
                      [string first + $cell] == -1} {
                # Destination is the same number as source.
                if {$checkOnly} {
                    return -level 2 true
                } else {
                    # When merging two tiles into one mark the new tile with
                    # the marker of "+" to ensure it doesn't get combined
                    # again this turn.
                    cell-set $newIndex [expr {2 * $cell}]+
                    set cell 0
                    incr changedCells
                }
            }
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
proc can-move? directionVect {
    move-all $directionVect 1
}

# Check win condition. The player wins when there's a 2048 tile.
proc check-win {} {
    forcells [cell-indexes] i j cell {
        if {$cell == 2048} {
            variable output "You win!\n"
            quit-game 0
        }
    }
}

# Check lose condition. The player loses when the win condition isn't met and
# there are no possible moves.
proc check-lose possibleMoves {
    if {![llength $possibleMoves]} {
        variable output "You lose.\n"
        quit-game 0
    }
}

# Pretty-print the board. Specify an index in highlight to highlight a cell.
proc print-board {{highlight {-1 -1}}} {
    forcells [cell-indexes] i j cell {
        if {$j == 0} {
            append res \n
        }
        append res [
            if {$cell != 0} {
                if {[struct::list equal [list $i $j] $highlight]} {
                    format {[%3s*]} $cell
                } else {
                    format {[%4s]} $cell
                }
            } else {
                lindex ......
            }
        ]
    }
    append res \n
}

# Exit game with a return status.
proc quit-game status {
    vars done inputMethod inputmode_save output playing stty_save turns
    #after cancel $playing
    #chan event stdin readable {}
    puts $output[set output {}]
    puts [list $turns turns]
    set turns 0
    switch $inputMethod {
        twapi {
            twapi::modify_console_input_mode stdin {*}$inputmode_save
        }
        raw {
            if {$inputmode_save ne {}} {
                exec stty $inputmode_save 2>@stderr
            }
        }
    }
    set done $status
    exit 0
}

# Event-driven input. Called when a key is pressed by the player.
proc input {} {
    vars inputMethod output playing
    variable playerInput [read stdin 1]
    if {[set charcode [scan $playerInput %c]] in [list 10 {}]} {
        if {$charcode eq 10 && $inputMethod ne {}} {
            #this only happens in raw/twapi mode.  add a newline to stdout
            append output \n
        }
        set playerInput {}
    }
    after cancel $playing
    play-user
}

# Process user input at the start of the game or during play.
proc play-user {} {
    vars controls inputMethod output playerInput playerMove \
        playType possibleMoves preferences size

    if {!$size} {
        # Game starting.
        set size $playerInput
        # Handle zero, one and non-digit input.
        if {$size eq "q"} {
            exit 0
        }
        if {![string is digit $size] || $size == 1} {
            set size 0
        }
        if {$size == 0} {
            return
        }
        # Default size on <enter>.
        if {$size eq {}} {
            set size 4
        }
        # Generate an empty board of a given size.
        board add columns $size
        board add rows $size
        forcells [cell-indexes] i j cell {
            set cell 0
        }

        after idle start-turn
        return
    }

    switch [scan $playerInput %c] {
        3 {
            if {$playType eq random} {
                set playType user
            } else {
                quit-game 0
            }
        }
    }
    if {[dict exists $preferences $playerInput]} {
        switch $playerInput {
            q {
                quit-game 0
            }
            r {
                set playType random
                after idle [namespace code play-random]
                return
            }
            ? {
                append output $controls\n
                append output $preferences\n
            }
        }
    } elseif {$playerInput in $possibleMoves} {
        set playerMove [dict get $controls $playerInput]
    }
    complete-turn
}

# Set user input to a random possible move.
proc play-random {} {
    vars controls playing playerInput possibleMoves
    variable delay 1000
    set playerInput [pick $possibleMoves]
    play-user
    set playing [after $delay [namespace code play-random]]
}

# Apply player's move, if any, and incr turn counter.
proc complete-turn {} {
    vars playerMove turns
    if {$playerMove eq {}} {
        flush stdout
        start-turn 0
    } else {
        incr turns
        # Apply current move until no changes occur on the board.
        while true {
            if {[move-all $playerMove] == 0} break
        }
        start-turn
    }
}

# Render board, find possible moves, add new tile, check win/lose.
proc start-turn {{makeNewTile 1}} {
    vars controls inputMethod output ingame newTile
    variable playerMove {}
    variable possibleMoves {}
    #buffer output to speed up rending on slower terminals
    if {!$ingame} {
        puts {Press "?" at any time after entering board size for help.}
        puts {Press "q" to quit.}
        puts {Select board size (4)}
        set ingame 1
        return
    }

    switch $inputMethod {
        twapi {
            twapi::clear_console stdout
        }
        raw {
            ::term::ansi::send::clear
        }
    }

    # Add new tile to the board and print the board highlighting this tile.
    if {$makeNewTile} {
        set newTile [spawn-new]
    }
    append output \n[print-board $newTile]
    check-win

    # Find possible moves.
    foreach {button vector} $controls {
        if {[can-move? $vector]} {
            lappend possibleMoves $button
        }
    }
    check-lose $possibleMoves

    append output "\nMove ("
    foreach {button vector} $controls {
        if {$button in $possibleMoves} {
            append output $button
        }
    }
    append output {)? }
    puts -nonewline $output[set output {}]
    flush stdout
}

# Set up game board and controls.
proc init {} {
    # Board size.
    variable size 0
    variable playmode play-user
    variable cell
    variable delay 0
    variable ingame 0
    variable playing {}
    variable playType user
    variable turns 0

    struct::matrix board

    variable inputmode_save {}
    variable inputMethod {}
    chan configure stdin -blocking 0
    if {![catch {package require twapi}]} {
        set inputmode_save [twapi::get_console_input_mode stdin]
        twapi::modify_console_input_mode stdin -lineinput false \
            -echoinput false
        set inputMethod twapi
    } else {
        catch {
            if {[auto_execok stty] ne {}} {
                if {[catch {set inputmode_save [
                    exec stty -g 2>@stderr]} eres eopts]} {
                    return
                    #todo: find other ways to save terminal state
                }
                package require term::ansi::ctrl::unix
                package require term::ansi::send
                term::ansi::ctrl::unix::raw
                set inputMethod raw
            }
        }
    }

    variable controls {
        h {0 -1}
        j {1 0}
        k {-1 0}
        l {0 1}
    }

    variable preferences {
        q quit
        r {random play
            You can speed through random play by pressing "r" in quick
            succession

            press any other valid input key to interrupt random play
        }
        ? {help
        }
    }

    start-turn
    chan event stdin readable [namespace code input]
}

proc main {} {
    variable done
    interp bgerror {} [namespace code bgerror]
    after idle init
    vwait [namespace current]::done
    exit $done
}

# Output error and quit.
proc bgerror args {
    puts stderr $::errorInfo
    quit-game 1
}

# Check if we were run as the primary script by the interpreter.
# From http://wiki.tcl.tk/40097.
proc main-script? {} {
    global argv0
    if {[info exists argv0]
     && [file exists [info script]] && [file exists $argv0]} {
        file stat $argv0 argv0Info
        file stat [info script] scriptInfo
        expr {$argv0Info(dev) == $scriptInfo(dev)
           && $argv0Info(ino) == $scriptInfo(ino)}
    } else {
        return 0
    }
}

if {[main-script?]} {
    main
}
