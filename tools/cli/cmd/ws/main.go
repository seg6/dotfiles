package main

import (
	"context"
	"fmt"
	"os"

	"github.com/seg6/dotfiles/tools/cli/internal/ws"
)

func main() {
	app, err := ws.NewApp()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ws: "+err.Error())
		os.Exit(1)
	}

	if err := app.Run(context.Background(), os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "ws: "+err.Error())
		os.Exit(1)
	}
}
