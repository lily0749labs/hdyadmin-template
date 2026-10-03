package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadEnvFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), ".env.local")
	content := []byte(`# 注释
PLAIN=value
export EXPORTED=enabled
SINGLE='single value'
DOUBLE="double value"
INLINE=value-with-comment # 说明
EMPTY=
`)
	if err := os.WriteFile(path, content, 0o600); err != nil {
		t.Fatalf("write test env: %v", err)
	}

	for _, key := range []string{"PLAIN", "EXPORTED", "SINGLE", "DOUBLE", "INLINE", "EMPTY"} {
		t.Setenv(key, "")
		if err := os.Unsetenv(key); err != nil {
			t.Fatalf("unset %s: %v", key, err)
		}
	}
	if err := loadEnvFile(path); err != nil {
		t.Fatalf("loadEnvFile() error = %v", err)
	}

	want := map[string]string{
		"PLAIN":    "value",
		"EXPORTED": "enabled",
		"SINGLE":   "single value",
		"DOUBLE":   "double value",
		"INLINE":   "value-with-comment",
		"EMPTY":    "",
	}
	for key, expected := range want {
		if got := os.Getenv(key); got != expected {
			t.Errorf("%s = %q, want %q", key, got, expected)
		}
	}
}

func TestLoadEnvFilePreservesExistingEnvironment(t *testing.T) {
	path := filepath.Join(t.TempDir(), ".env.local")
	if err := os.WriteFile(path, []byte("EXISTING=from-file\n"), 0o600); err != nil {
		t.Fatalf("write test env: %v", err)
	}
	t.Setenv("EXISTING", "from-process")

	if err := loadEnvFile(path); err != nil {
		t.Fatalf("loadEnvFile() error = %v", err)
	}
	if got := os.Getenv("EXISTING"); got != "from-process" {
		t.Fatalf("EXISTING = %q, want process value", got)
	}
}

func TestLoadEnvFileRejectsInvalidLine(t *testing.T) {
	path := filepath.Join(t.TempDir(), ".env.local")
	if err := os.WriteFile(path, []byte("NOT AN ASSIGNMENT\n"), 0o600); err != nil {
		t.Fatalf("write test env: %v", err)
	}

	if err := loadEnvFile(path); err == nil {
		t.Fatal("loadEnvFile() error = nil, want parse error")
	}
}
