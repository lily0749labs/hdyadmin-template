package server

import (
	"os"
	"path/filepath"
	"testing"
)

func TestHTTPListenAddr(t *testing.T) {
	t.Setenv("MODULE_HTTP_ADDR", "")
	if got := httpListenAddr(); got != defaultHTTPListenAddr {
		t.Fatalf("httpListenAddr() = %q, want %q", got, defaultHTTPListenAddr)
	}

	t.Setenv("MODULE_HTTP_ADDR", "0.0.0.0:18080")
	if got := httpListenAddr(); got != "0.0.0.0:18080" {
		t.Fatalf("httpListenAddr() = %q, want explicit address", got)
	}
}

func TestPublishRuntimeEndpoint(t *testing.T) {
	runtimeDir := t.TempDir()
	t.Setenv("MODULE_RUNTIME_DIR", runtimeDir)

	const endpoint = "http://127.0.0.1:43210"
	cleanup, err := publishRuntimeEndpoint(endpoint)
	if err != nil {
		t.Fatalf("publishRuntimeEndpoint() error = %v", err)
	}

	path := filepath.Join(runtimeDir, runtimeEndpointFile)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read runtime endpoint: %v", err)
	}
	if got := string(data); got != endpoint+"\n" {
		t.Fatalf("runtime endpoint = %q, want %q", got, endpoint+"\n")
	}

	cleanup()
	if _, err = os.Stat(path); !os.IsNotExist(err) {
		t.Fatalf("runtime endpoint still exists after cleanup: %v", err)
	}
}

func TestRuntimeEndpointCleanupPreservesNewerProcess(t *testing.T) {
	runtimeDir := t.TempDir()
	t.Setenv("MODULE_RUNTIME_DIR", runtimeDir)

	cleanupOld, err := publishRuntimeEndpoint("http://127.0.0.1:41001")
	if err != nil {
		t.Fatalf("publish old endpoint: %v", err)
	}
	cleanupNew, err := publishRuntimeEndpoint("http://127.0.0.1:41002")
	if err != nil {
		t.Fatalf("publish new endpoint: %v", err)
	}

	cleanupOld()
	path := filepath.Join(runtimeDir, runtimeEndpointFile)
	if _, err = os.Stat(path); err != nil {
		t.Fatalf("old cleanup removed newer endpoint: %v", err)
	}

	cleanupNew()
}
