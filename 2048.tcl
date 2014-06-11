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

proc forcells {varName1 varName2 cellVarName size script} {
	upvar $varName1 i
	upvar $varName2 j
	upvar $cellVarName c
	for {set i 0} {$i < $size} {incr i} {
		for {set j 0} {$j < $size} {incr j} {
			set c [field get cell $i $j]
			uplevel $script
			field set cell $i $j $c
		}
	}
}

proc cell-indexes {} {
	global size
	set list {}
	for {set i 0} {$i < $size} {incr i} {
		for {set j 0} {$j < $size} {incr j} {
			lappend list [list $i $j]
		}
	}
	return $list
}

proc cell-query {vect} {
	set res {}
	set err [
		catch {
			set res [field get cell [expr $i + $offsetX] [expr $j + $offsetY]]
		} msg
	]
	puts "$err $res"
	if {! $err} {
		return $res
	} else {
		return
	}
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

proc nonempty {} {
	::struct::list filterfor x [cell-indexes] {[cell-value $x] ne 0}
}

proc adjacent-to-nonempty {} {
	uniq [::struct::list flatten [::struct::list map [nonempty] adjacent]]
}

struct::matrix field
field add columns $size
field add rows $size

forcells i j cell $size {
	set cell [expr $i*$j]
}
puts [field format 2string]
puts [adjacent-to-nonempty]