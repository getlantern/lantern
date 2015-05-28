package main

import (
	"fmt"
	"strings"
)

//-------------------------------------------------------------------------
// formatter interfaces
//-------------------------------------------------------------------------

type formatter interface {
	write_candidates(candidates []candidate, num int)
}

//-------------------------------------------------------------------------
// nice_formatter (just for testing, simple textual output)
//-------------------------------------------------------------------------

type nice_formatter struct{}

func (*nice_formatter) write_candidates(candidates []candidate, num int) {
	if candidates == nil {
		fmt.Printf("Nothing to complete.\n")
		return
	}

	fmt.Printf("Found %d candidates:\n", len(candidates))
	for _, c := range candidates {
		abbr := fmt.Sprintf("%s %s %s", c.Class, c.Name, c.Type)
		if c.Class == decl_func {
			abbr = fmt.Sprintf("%s %s%s", c.Class, c.Name, c.Type[len("func"):])
		}
		fmt.Printf("  %s\n", abbr)
	}
}

//-------------------------------------------------------------------------
// vim_formatter
//-------------------------------------------------------------------------

type vim_formatter struct{}

func (*vim_formatter) write_candidates(candidates []candidate, num int) {
	if candidates == nil {
		fmt.Print("[0, []]")
		return
	}

	fmt.Printf("[%d, [", num)
	for i, c := range candidates {
		if i != 0 {
			fmt.Printf(", ")
		}

		word := c.Name
		if c.Class == decl_func {
			word += "("
			if strings.HasPrefix(c.Type, "func()") {
				word += ")"
			}
		}

		abbr := fmt.Sprintf("%s %s %s", c.Class, c.Name, c.Type)
		if c.Class == decl_func {
			abbr = fmt.Sprintf("%s %s%s", c.Class, c.Name, c.Type[len("func"):])
		}
		fmt.Printf("{'word': '%s', 'abbr': '%s', 'info': '%s'}", word, abbr, abbr)
	}
	fmt.Printf("]]")
}

//-------------------------------------------------------------------------
// godit_formatter
//-------------------------------------------------------------------------

type godit_formatter struct{}

func (*godit_formatter) write_candidates(candidates []candidate, num int) {
	fmt.Printf("%d,,%d\n", num, len(candidates))
	for _, c := range candidates {
		contents := c.Name
		if c.Class == decl_func {
			contents += "("
			if strings.HasPrefix(c.Type, "func()") {
				contents += ")"
			}
		}

		display := fmt.Sprintf("%s %s %s", c.Class, c.Name, c.Type)
		if c.Class == decl_func {
			display = fmt.Sprintf("%s %s%s", c.Class, c.Name, c.Type[len("func"):])
		}
		fmt.Printf("%s,,%s\n", display, contents)
	}
}

//-------------------------------------------------------------------------
// emacs_formatter
//-------------------------------------------------------------------------

type emacs_formatter struct{}

func (*emacs_formatter) write_candidates(candidates []candidate, num int) {
	for _, c := range candidates {
		var hint string
		switch {
		case c.Class == decl_func:
			hint = c.Type
		case c.Type == "":
			hint = c.Class.String()
		default:
			hint = c.Class.String() + " " + c.Type
		}
		fmt.Printf("%s,,%s\n", c.Name, hint)
	}
}

//-------------------------------------------------------------------------
// csv_formatter
//-------------------------------------------------------------------------

type csv_formatter struct{}

func (*csv_formatter) write_candidates(candidates []candidate, num int) {
	for _, c := range candidates {
		fmt.Printf("%s,,%s,,%s\n", c.Class, c.Name, c.Type)
	}
}

//-------------------------------------------------------------------------
// json_formatter
//-------------------------------------------------------------------------

type json_formatter struct{}

func (*json_formatter) write_candidates(candidates []candidate, num int) {
	if candidates == nil {
		fmt.Print("[]")
		return
	}

	fmt.Printf(`[%d, [`, num)
	for i, c := range candidates {
		if i != 0 {
			fmt.Printf(", ")
		}
		fmt.Printf(`{"class": "%s", "name": "%s", "type": "%s"}`,
			c.Class, c.Name, c.Type)
	}
	fmt.Print("]]")
}

//-------------------------------------------------------------------------

func get_formatter(name string) formatter {
	switch name {
	case "vim":
		return new(vim_formatter)
	case "emacs":
		return new(emacs_formatter)
	case "nice":
		return new(nice_formatter)
	case "csv":
		return new(csv_formatter)
	case "json":
		return new(json_formatter)
	case "godit":
		return new(godit_formatter)
	}
	return new(nice_formatter)
}
