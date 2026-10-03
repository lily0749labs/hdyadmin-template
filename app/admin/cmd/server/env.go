package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"unicode"
)

// loadEnvFile 加载简单的 dotenv 文件，但不覆盖进程中已经显式设置的环境变量。
// 支持空行、注释、export 前缀以及单引号或双引号包裹的值。
func loadEnvFile(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("open module environment file %q: %w", path, err)
	}
	defer func() { _ = file.Close() }()

	scanner := bufio.NewScanner(file)
	for lineNumber := 1; scanner.Scan(); lineNumber++ {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		line = strings.TrimSpace(strings.TrimPrefix(line, "export "))

		key, rawValue, found := strings.Cut(line, "=")
		key = strings.TrimSpace(key)
		if !found || !validEnvKey(key) {
			return fmt.Errorf("parse module environment file %q line %d: invalid assignment", path, lineNumber)
		}
		if _, exists := os.LookupEnv(key); exists {
			continue
		}

		value, err := parseEnvValue(strings.TrimSpace(rawValue))
		if err != nil {
			return fmt.Errorf("parse module environment file %q line %d: %w", path, lineNumber, err)
		}
		if err = os.Setenv(key, value); err != nil {
			return fmt.Errorf("set environment variable %s: %w", key, err)
		}
	}
	if err = scanner.Err(); err != nil {
		return fmt.Errorf("read module environment file %q: %w", path, err)
	}
	return nil
}

// parseEnvValue 解析 dotenv 值；未加引号的行内注释必须由空白加 # 开始。
func parseEnvValue(value string) (string, error) {
	if value == "" {
		return "", nil
	}
	if value[0] == '\'' {
		if len(value) < 2 || value[len(value)-1] != '\'' {
			return "", fmt.Errorf("unterminated single-quoted value")
		}
		return value[1 : len(value)-1], nil
	}
	if value[0] == '"' {
		parsed, err := strconv.Unquote(value)
		if err != nil {
			return "", fmt.Errorf("invalid double-quoted value: %w", err)
		}
		return parsed, nil
	}
	if comment := strings.Index(value, " #"); comment >= 0 {
		value = value[:comment]
	}
	return strings.TrimSpace(value), nil
}

// validEnvKey 限制变量名为 Shell、Make 和 Go 都能一致识别的形式。
func validEnvKey(key string) bool {
	for index, character := range key {
		if character == '_' || unicode.IsLetter(character) || (index > 0 && unicode.IsDigit(character)) {
			continue
		}
		return false
	}
	return key != ""
}
