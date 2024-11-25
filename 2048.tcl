#! /usr/bin/env tclsh
# The game 2048 implemented in Tcl.
# Version 1.0.0.
#
# This code is released under the terms of the MIT license.
# See the file LICENSE for details.
#
# More at:
# - https://github.com/dbohdan/2048.tcl -- Git repository
# - https://wiki.tcl-lang.org/40557 -- discussion

package require Tcl 8.6 9

namespace eval 2048 {
    namespace ensemble create
    namespace export *

    # Utility procs.

    proc vars args {
        foreach varname $args {
            uplevel [list variable $varname]
        }
    }

    # Pick a random item from the given list.
    proc pick list {
        lindex $list [expr {int(rand() * [llength $list])}]
    }

    # An abstraction representing the game board. Operates at the level of cells
    # containing numerical values, not movable game tiles.
    namespace eval board {
        namespace ensemble create
        namespace export *

        variable data {}
        variable size 0

        # Iterate over every cell of the game board and run $script for each.
        #
        # The game board is a 2D matrix of a fixed size that consists of
        # elements called "cells" that each can contain a number.
        #
        # - $cellList is a list of cell indexes (coordinates), which are
        # themselves lists of two numbers each. They each represent the location
        # of a given cell on the board.
        # - $varName1 and $varName2 are the names of the variables that will be
        # assigned the current cell's indexes when running the script.
        # - $cellVarName is the name of the variable that at each step will
        # contain the numerical value of the current cell. Assigning to it
        # will change the cell's value.
        # - $script is the script to run.
        proc forcells {cellList varName1 varName2 cellVarName script} {
            upvar $varName1 i
            upvar $varName2 j
            upvar $cellVarName c
            foreach cell $cellList {
                lassign $cell i j
                set c [get-cell $cell]

                try {
                    uplevel $script
                } on ok {res opts} - \
                  on error {res opts} - \
                  on break {res opts} - \
                  on continue {res opts} {
                    return -options $opts $res
                } on return {res opts} {
                    return -options [dict replace $opts -level 2] $res
                }

                set-cell [list $i $j] $c
            }
        }

        # Generate a list of cell indexes for every cell of the board. The order
        # in which the cell indexes appear depends on the value of
        # $directionVect. E.g., if $directionVect is {1 1} the list will be
        # {{0 0} {0 1} ... {0 size-1} {1 0} {1 1} ... {size-1 size-1}}
        proc indexes {{directionVect {1 1}}} {
            variable size

            lassign $directionVect delta(i) delta(j)
            foreach varName {i j} {
                switch -exact -- $delta($varName) {
                    1 {
                        set start($varName) 0
                        set end($varName)   $size
                    }
                    -1 {
                        set start($varName) [expr {$size - 1}]
                        set end($varName)   -1
                    }
                    default {
                        error "direction vector must be {?-?1 ?-?1}"
                    }
                }
            }

            set list {}
            for {set i $start(i)} {$i != $end(i)} {incr i $delta(i)} {
                for {set j $start(j)} {$j != $end(j)} {incr j $delta(j)} {
                    lappend list [list $i $j]
                }
            }
            return $list
        }

        # Check if the list $cell represents a valid pair of cell coordinates.
        proc valid-cell? cell {
            variable size
            lassign $cell i j
            return [expr {(0 <= $i) && ($i < $size) &&
                          (0 <= $j) && ($j < $size)}]
        }

        # Prepare the board for use. Must be called before any other board
        # procs.
        proc init boardSize {
            variable data
            variable size
            set size $boardSize
            for {set i 0} {$i < $size} {incr i} {
                for {set j 0} {$j < $size} {incr j} {
                    set-cell [list $i $j] 0
                }
            }
        }

        # Get the value of a game board cell.
        proc get-cell cell {
            variable data
            dict get $data $cell
        }

        # Set the value of a game board cell.
        proc set-cell {cell value} {
            variable data
            dict set data $cell $value
        }

        # Filter the list of board cell indexes $cellList to only have those
        # indexes that correspond to empty board cells.
        proc empty cellList {
            set resultList {}
            foreach cell $cellList {
                if {[get-cell $cell] == 0} {
                    lappend resultList $cell
                }
            }
            return $resultList
        }

        # Pretty-print the board. Specify an index in $highlight to highlight a
        # cell with a "*" after its contents.
        proc print {{highlight {-1 -1}}} {
            forcells [indexes] i j cell {
                if {$j == 0} {
                    append res \n
                }
                append res [
                    if {$cell != 0} {
                        if {($i == [lindex $highlight 0]) &&
                                ($j == [lindex $highlight 1])} {
                            format {[%3s*]} $cell
                        } else {
                            format {[%4s]} $cell
                        }
                    } else {
                        lindex "......"
                    }
                ]
            }
            append res \n
        }
    } ;# namespace board

    # Game logic.
    namespace eval game-logic {
        namespace ensemble create
        namespace export *
    }

    # Put a "2" into an empty cell on the board.
    proc spawn-new-tile {} {
        set emptyCell [pick [board empty [board indexes]]]
        if {[llength $emptyCell] > 0} {
            board set-cell $emptyCell 2
        }
        return $emptyCell
    }

    # If $checkOnly is false try to shift all cells one step in the direction of
    # $directionVect. If $checkOnly is true just say if that move is possible.
    proc move-all-tiles {directionVect {checkOnly 0}} {
        set changedCells 0
        lassign $directionVect di dj

        # Traverse the board in such a way that those tiles that are closer to
        # the edges are merged first.
        set indexDirVect [list \
                [expr {$di == 0 ? 1 : -$di}] [expr {$dj == 0 ? 1 : -$dj}]]
        board forcells [board indexes $indexDirVect] i j cell {
            set newIndex [list [expr {$i +  $di}] [expr {$j +  $dj}]]
            set removedStar 0

            # For every nonempty source cell and valid destination cell...
            if {$cell != 0 && [board valid-cell? $newIndex]} {
                if {[board get-cell $newIndex] == 0} {
                    # The destination is empty.
                    if {$checkOnly} {
                        return true
                    } else {
                        # Move the tile to the empty cell.
                        board set-cell $newIndex $cell
                        set cell 0
                        incr changedCells
                    }
                } elseif {([board get-cell $newIndex] eq $cell) &&
                          [string first + $cell] == -1} {
                    # The destination is the same number as the source.
                    if {$checkOnly} {
                        return -level 2 true
                    } else {
                        # When merging two tiles into one, mark the new tile
                        # with the marker of "+" to ensure it doesn't get
                        # combined again this turn.
                        board set-cell $newIndex [expr {2 * $cell}]+
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
            board forcells [board indexes] i j cell {
                set cell [string trim $cell +]
            }
        }
        return $changedCells
    }

    # Return the sum of the numbers on all tiles.
    proc score {} {
        set score 0
        board forcells [board indexes] i j cell {
            incr score $cell
        }
        return $score
    }

    # Is it possible to move any tiles in the direction of $directionVect?
    proc can-move? directionVect {
        move-all-tiles $directionVect 1
    }

    # Check the win condition. The player wins when there is a 2048 tile.
    proc check-win {} {
        board forcells [board indexes] i j cell {
            if {$cell == 2048} {
                variable output "You win!\n"
                quit-game 0
            }
        }
    }

    # Check the lose condition. The player loses when the win condition isn't
    # met and there are no possible moves.
    proc check-lose possibleMoves {
        # If not all board cells are empty and no possible moves remain...
        if {![llength $possibleMoves] &&
                ([board empty [board indexes]] ne [board indexes])} {
            variable output "You lose.\n"
            quit-game 0
        }
    }

    # Exit the game with an exit status.
    proc quit-game status {
        vars done inputMethod inputModeSaved output playing stty_save turns

        if [info exists output] {
            puts $output[set output {}]

            # Print the total number of turns played.
            set turnsMessage [list $turns turn]
            if {($turns % 10 != 1) || ($turns % 100 == 11)} {
                append turnsMessage s
            }
            puts "$turnsMessage. [score] points."
        }

        switch $inputMethod {
            twapi {
                twapi::modify_console_input_mode stdin {*}$inputModeSaved
            }
            raw {
                if {$inputModeSaved ne {}} {
                    exec stty $inputModeSaved 2>@stderr
                }
            }
        }
        set done $status
        exit $status
    }

    # Event-driven input. Called when the player pressed a key.
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

    # Process the user input at the start of the game or during play.
    proc play-user {} {
        vars controls inputMethod output playerInput playerMove \
            playType possibleMoves preferences size

        if {!$size} {
            # The game is starting.
            set size $playerInput
            # Handle zero, one and non-digit input.
            if {$size eq "q"} {
                quit-game 0
            }
            if {![string is digit $size] || $size == 1} {
                set size 0
            }
            if {$size == 0} {
                return
            }
            # Choose the default size on <enter>.
            if {$size eq {}} {
                set size 4
            }
            # Generate an empty board of a given size.
            board init $size

            after idle [namespace code start-turn]
            return
        }

        switch [scan $playerInput %c] {
            3 {
                if {$playType eq {random}} {
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
                    after idle [namespace code {play-random 0}]
                    return
                }
                R {
                    set playType random
                    after idle [namespace code {play-random 1}]
                    return
                }
                s {
                    append output "Score: [score]\n"
                }
                ? {
                    proc print-msg dictionary {
                        upvar 1 output output
                        foreach {key message} $dictionary {
                            append output "$key: $message\n"
                        }
                    }
                    append output \
                            "[join [dict keys $controls] {, }]: movement\n"
                    print-msg $preferences
                }
            }
        } elseif {$playerInput in $possibleMoves} {
            set playerMove [dict get $controls $playerInput]
        }
        complete-turn
    }

    # Set the user input to a random possible move.
    proc play-random {continuous} {
        vars controls playing playerInput possibleMoves
        variable delay 1000
        set playerInput [pick $possibleMoves]
        play-user
        if {$continuous} {
            set playing [after $delay [namespace code {play-random 1}]]
        }
    }

    # Apply the player's move, if any, and increment the turn counter.
    proc complete-turn {} {
        vars playerMove turns
        if {$playerMove eq {}} {
            flush stdout
            start-turn 0
        } else {
            incr turns
            # Apply the current move until no changes occur on the board.
            while true {
                if {[move-all-tiles $playerMove] == 0} break
            }
            start-turn
        }
    }

    # Render board, find possible moves, add new tile, check win/lose.
    proc start-turn {{makeNewTile 1}} {
        vars controls inputMethod output ingame newTile
        variable playerMove {}
        variable possibleMoves {}
        # Buffer the output to speed up the rending on slower terminals.
        if {!$ingame} {
            puts {Press "?" at any time after entering the board size for help.}
            puts {Press "q" to quit.}
            puts {Select board size (4)}
            set ingame 1
            return
        }

        switch $inputMethod {
            twapi {
                twapi::clear_console stdout
                twapi::set_console_cursor_position stdout {0 0}
            }
            raw {
                ::term::ansi::send::clear
            }
        }

        # Add a new tile to the board and print the board highlighting that
        # tile.
        if {$makeNewTile} {
            set newTile [spawn-new-tile]
        } elseif {![info exists newTile]} {
            set newTile {}
        }
        append output \n[board print {*}[list $newTile]]
        check-win

        # Find the possible moves.
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

    # Set up the game board and the controls.
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

        variable inputModeSaved {}
        variable inputMethod {}
        chan configure stdin -blocking 0

        try {
            package require twapi

            set inputModeSaved [twapi::get_console_input_mode stdin]
            twapi::modify_console_input_mode stdin -lineinput false \
                -echoinput false
            set inputMethod twapi
        } on error _ {
            catch {
                set inputModeSaved [exec stty -g 2>@stderr]
                # TODO: Find other ways to save the state of the
                # terminal.

                package require term::ansi::ctrl::unix
                package require term::ansi::send
                term::ansi::ctrl::unix::raw
                set inputMethod raw
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
            r {random move}
            R {automatic random play (input anything to stop)}
            s {show score}
            ? help
        }

        start-turn
        chan event stdin readable [namespace code input]
    }

    proc main {} {
        variable done
        interp bgerror {} [namespace code bgerror]
        after idle [namespace code init]
        vwait done
        exit $done
    }

    # Output error and quit.
    proc bgerror args {
        puts stderr $::errorInfo
        quit-game 1
    }
}

# Check if we were run as the primary script by the interpreter.
# From https://wiki.tcl-lang.org/40097.
proc main-script? {} {
    global argv0
    if {[info exists argv0] && [file exists [info script]] &&
            [file exists $argv0]} {
        file stat $argv0 argv0Info
        file stat [info script] scriptInfo

        # Adjust for running from a network drive on Windows.
        package require platform
        set platform [::platform::generic]
        set windows [string match *win* $platform]
        expr {($argv0Info(dev) == $scriptInfo(dev)) &&
                ($windows || ($argv0Info(ino) == $scriptInfo(ino)))}
    } else {
        return 0
    }
}

if {[main-script?]} {
    2048 main
}
