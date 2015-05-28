#!/usr/bin/env ruby
# encoding: utf-8

RED = "\033[0;31m"
GRN = "\033[0;32m"
NC  = "\033[0m"

PASS = "#{GRN}PASS!#{NC}"
FAIL = "#{RED}FAIL!#{NC}"

Stats = Struct.new :total, :ok, :fail
$stats = Stats.new 0, 0, 0

def print_fail_report(t, out, outexpected)
	puts "#{t}: #{FAIL}"
	puts "-"*65
	puts "Got:\n#{out}"
	puts "-"*65
	puts "Expected:\n#{outexpected}"
	puts "-"*65
end

def print_pass_report(t)
	puts "#{t}: #{PASS}"
end

def print_stats
	puts "\nSummary (total: #{$stats.total})"
	puts "#{GRN}  PASS#{NC}: #{$stats.ok}"
	puts "#{RED}  FAIL#{NC}: #{$stats.fail}"
	puts "#{$stats.fail == 0 ? GRN : RED}#{"█"*72}#{NC}"
end

def run_test(t)
	$stats.total += 1

	cursorpos = Dir["#{t}/cursor.*"].map{|d| File.extname(d)[1..-1]}.first
	outexpected = IO.read("#{t}/out.expected") rescue "To be determined"
	filename = "#{t}/test.go.in"

	out = %x[gocode -in #{filename} autocomplete #{filename} #{cursorpos}]

	if out != outexpected then
		print_fail_report(t, out, outexpected)
		$stats.fail += 1
	else
		print_pass_report(t)
		$stats.ok += 1
	end
end

if ARGV.one?
	run_test ARGV[0]
else
	Dir["test.*"].sort.each do |t| 
		run_test t
	end
end

print_stats
