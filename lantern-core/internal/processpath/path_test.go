package processpath

import (
	"regexp"
	"strings"
	"testing"
)

func TestBuildAliasPattern(t *testing.T) {
	parts := []string{`C:`, `Games [1]`, `游戏 (beta)+`, `Game Client.exe`}
	aliases := []string{"", `GAMES~1`, `GAMEBE~1`, `GAMECL~1.EXE`}
	pattern := buildAliasPattern(parts, aliases)
	if !IsAliasPattern(pattern) {
		t.Fatalf("missing managed-rule marker: %q", pattern)
	}
	rule, err := regexp.Compile(pattern)
	if err != nil {
		t.Fatal(err)
	}
	for mask := range 1 << (len(parts) - 1) {
		variant := append([]string(nil), parts...)
		for i := 1; i < len(parts); i++ {
			if mask&(1<<(i-1)) != 0 {
				variant[i] = aliases[i]
			}
		}
		for _, path := range []string{strings.Join(variant, `\`), strings.ToUpper(strings.Join(variant, `\`))} {
			if !rule.MatchString(path) {
				t.Errorf("pattern does not match %q", path)
			}
		}
	}
	for _, path := range []string{
		`C:\Other Games\游戏 (beta)+\Game Client.exe`,
		`C:\Games [1]\游戏 (beta)+\Other.exe`,
		`C:\Games 1\游戏 (beta)+\Game Client.exe`,
		`C:\Games [1]\游戏 betaaa\Game Client.exe`,
		`C:\Games [1]\游戏 (beta)+\Game ClientXexe`,
		`C:\Games [1]\游戏 (beta)+\Game Client.exe.bak`,
		`D:\Games [1]\游戏 (beta)+\Game Client.exe`,
		`prefixC:\Games [1]\游戏 (beta)+\Game Client.exe`,
		"C:\\Games [1]\\游戏 (beta)+\\Game Client.exe\n",
	} {
		if rule.MatchString(path) {
			t.Errorf("pattern matches unrelated path %q", path)
		}
	}
}

func TestBuildAliasPatternWithoutAliases(t *testing.T) {
	parts := []string{`C:`, `Games`, `Game.exe`}
	for _, aliases := range [][]string{nil, {"", "", ""}, {"", "GAMES", "GAME.EXE"}} {
		if got := buildAliasPattern(parts, aliases); got != "" {
			t.Errorf("aliases %q produced unnecessary pattern %q", aliases, got)
		}
	}
}

func TestIsAliasPattern(t *testing.T) {
	for _, pattern := range []string{"", `(?i)^C:\\Games\\.*`, `lantern_windows_executable`, `^(?P<other>)C:\\Game.exe$`} {
		if IsAliasPattern(pattern) {
			t.Errorf("claimed user-defined rule %q", pattern)
		}
	}
}
