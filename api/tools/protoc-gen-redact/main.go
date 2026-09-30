// Command protoc-gen-redact adapts the installed Redact plugin to Go's module output option.
package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path"
	"strings"

	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/pluginpb"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "protoc-gen-redact adapter:", err)
		os.Exit(1)
	}
}

func run() error {
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		return err
	}
	request := new(pluginpb.CodeGeneratorRequest)
	if err := proto.Unmarshal(input, request); err != nil {
		return err
	}

	var module string
	var parameters []string
	for _, parameter := range strings.Split(request.GetParameter(), ",") {
		switch {
		case strings.HasPrefix(parameter, "module="):
			module = strings.TrimSuffix(strings.TrimPrefix(parameter, "module="), "/")
		case parameter == "paths=source_relative":
			return fmt.Errorf("module requires import-based output paths")
		case parameter != "":
			parameters = append(parameters, parameter)
		}
	}
	if module == "" {
		return fmt.Errorf("module option is required")
	}
	request.Parameter = proto.String(strings.Join(parameters, ","))
	input, err = proto.Marshal(request)
	if err != nil {
		return err
	}

	command := exec.Command("protoc-gen-redact")
	command.Stdin = bytes.NewReader(input)
	command.Stderr = os.Stderr
	output, err := command.Output()
	if err != nil {
		return fmt.Errorf("run installed plugin: %w", err)
	}
	response := new(pluginpb.CodeGeneratorResponse)
	if err := proto.Unmarshal(output, response); err != nil {
		return err
	}
	if response.GetError() == "" {
		prefix := module + "/"
		for _, file := range response.File {
			name := file.GetName()
			if !strings.HasPrefix(name, prefix) {
				return fmt.Errorf("output %q is outside module %q", name, module)
			}
			name = strings.TrimPrefix(name, prefix)
			if name == "." || name == "" || path.IsAbs(name) || path.Clean(name) != name || strings.HasPrefix(name, "../") {
				return fmt.Errorf("invalid relative output path %q", name)
			}
			file.Name = proto.String(name)
		}
	}
	output, err = proto.Marshal(response)
	if err != nil {
		return err
	}
	_, err = os.Stdout.Write(output)
	return err
}
