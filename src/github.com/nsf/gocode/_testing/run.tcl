#!/usr/bin/env tclsh

set red "\033\[0;31m"
set grn "\033\[0;32m"
set nc  "\033\[0m"

set pass "${grn}PASS!${nc}"
set fail "${red}FAIL!${nc}"

set stats.total 0
set stats.ok 0
set stats.fail 0

proc print_fail_report {t out expected} {
	global fail

	set hr [join [lrepeat 65 "-"] ""]
	puts "${t}: ${fail}"
	puts $hr
	puts "Got:\n${out}"
	puts $hr
	puts "Expected:\n${expected}"
	puts $hr
}

proc print_pass_report {t} {
	global pass

	puts "${t}: ${pass}"
}

proc print_stats {} {
	global red grn nc stats.total stats.ok stats.fail

	set hr [join [lrepeat 72 "█"] ""]
	set hrcol [expr {${stats.fail} ? $red : $grn}]
	puts "\nSummary (total: ${stats.total})"
	puts "${grn}  PASS${nc}: ${stats.ok}"
	puts "${red}  FAIL${nc}: ${stats.fail}"
	puts "${hrcol}${hr}${nc}"
}

proc read_file {filename} {
	set f [open $filename r]
	set data [read $f]
	close $f
	return $data
}

proc run_test {t} {
	global stats.total stats.ok stats.fail

	incr stats.total
	set cursorpos [string range [file extension [glob "${t}/cursor.*"]] 1 end]
	set expected [read_file "${t}/out.expected"]
	set filename "${t}/test.go.in"

	set out [read_file "| gocode -in ${filename} autocomplete ${filename} ${cursorpos}"]
	if {$out eq $expected} {
		print_pass_report $t
		incr stats.ok
	} else {
		print_fail_report $t $out $expected
		incr stats.fail
	}
}

if {$argc == 1} {
	run_test $argv
} else {
	foreach t [lsort [glob test.*]] {
		run_test $t
	}
}

print_stats


