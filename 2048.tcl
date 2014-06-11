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
		set c [field get cell {*}$cell]
		uplevel $script
		field set cell $i $j $c
	}
}

proc cell-indexes {{directionVect {0 0}}} {
	global size
	set list {}
	set range0 [::struct::list iota $size]
	set range1 [::struct::list iota $size]
	foreach r {0 1} {
		if {[lindex $directionVect $r] > 0} {
			set range$r [::struct::list reverse [set range$r]]
		}
	}
	foreach i $range0 {
		foreach j $range1 {
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
		set cell 1
	}
}

proc move-all {directionVect} {
	forcells [cell-indexes $directionVect] i j cell {
		set new-index [vector-add [field get cell {*}$cell] $directionVect]
		if {[cell-value $new-index] == 0} {
			field set cell {*}$new-index $cell
			set cell 0
		} elseif {[cell-value $new-index] == $c} {
			field set cell {*}$new-index [expr {2 * $c}]
			set cell 0
		}
	}
}

struct::matrix field
field add columns $size
field add rows $size

forcells [cell-indexes] i j cell {
	set cell 0
}
forcells [list [pick [cell-indexes]]] i j cell {
	set cell 1
}


puts [field format 2string]