package main

import (
	"os"

	"github.com/seg6/dotfiles/tools/cli/internal/theme"
)

func main() {
	theme.Run(os.Args[1:])
}
