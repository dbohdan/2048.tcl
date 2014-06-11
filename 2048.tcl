# A minimal implementation of the game 2048 in Tcl
package require Tcl 8.2
package require struct::matrix
package require struct::list

set size 4

proc vector-add {v1 v2} {
	set result {}
	foreach a $v1 b $v2 {
		lappend result [expr {$a + $b}]
	}
	return $result
}

proc forcells {cellList varName1 varName2 cellVarName script} {
	upvar $varName1 i
	upvar $varName2 j
	upvar $cellVarName c
	foreach cell $cellList {
		set i [lindex $cell 0]
		set j [lindex $cell 1]
		set c [cell-value $cell]
		uplevel $script
		cell-set "$i $j" $c
	}
}

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

proc adjacent {vect} {
	set adjacentList {}
	foreach offset {{-1 0} {1 0} {0 -1} {0 1}} {
		lappend adjacentList [vector-add $vect $offset]
	}
	return [::struct::list filter $adjacentList valid-indexes]
}

proc cell-value cell {
	field get cell {*}$cell
}

proc cell-set {cell value} {
	field set cell {*}$cell $value
}

proc uniq {list} {
    lsort -unique $list
}

proc empty {cellList} {
	::struct::list filterfor x $cellList {[cell-value $x] == 0}
}
proc nonempty {cellList} {
	::struct::list filterfor x $cellList {[cell-value $x] != 0}
}

proc adjacent-to-nonempty {cellList} {
	uniq [::struct::list flatten [::struct::list map [nonempty $cellList] adjacent]]
}

proc pick list {
	lindex $list [expr {int(rand() * [llength $list])}]
}

proc spawn-one {} {
	forcells [list [pick [empty [adjacent-to-nonempty [cell-indexes]]]]] i j cell {
		set cell 1*
	}
}

proc move-all {directionVect} {
	set changedCells 0
	forcells [cell-indexes] i j cell {
		set newIndex [vector-add "$i $j" $directionVect]
		if {$cell eq {1*}} {
			set cell 1
		}
		if {$cell != 0 && [valid-indexes $newIndex]} {
			if {[cell-value $newIndex] == 0} {
				cell-set $newIndex $cell
				set cell 0
				incr changedCells
			} elseif {[cell-value $newIndex] == $cell} {
				cell-set $newIndex [expr {2 * $cell}]
				set cell 0
				incr changedCells
			}
		}
	}
	return $changedCells
}

struct::matrix field
field add columns $size
field add rows $size

# Generate starting field
forcells [cell-indexes] i j cell {
	set cell 0
}
forcells [list [pick [cell-indexes]]] i j cell {
	set cell 1
}

# Game loop.
while 1 {
	set playerMove 0
	puts [field format 2string]
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
	while 1 {
		if {[move-all $playerMove] == 0} break
	}
	spawn-one
}