package server

import (
	"fmt"
	"io/fs"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	kratosHTTP "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	domainpb "github.com/neo-fork-gotangra/hdyadmin-template/api/pb/domain"
	"github.com/neo-fork-gotangra/hdyadmin-template/app/admin/cmd/server/assets"
	"github.com/neo-fork-gotangra/hdyadmin-template/app/admin/internal/service"
)

const (
	// 默认让操作系统分配空闲端口，避免从模板创建的多个模块互相冲突。
	defaultHTTPListenAddr = "127.0.0.1:0"
	runtimeEndpointFile   = "http-endpoint"
)

// NewHTTPServer 提供健康检查、模块注册资源和内嵌的远程前端文件。
// 独立运行模式下，它还会开放通常由 Core 转发到 gRPC 的业务 HTTP 路由。
func NewHTTPServer(
	ctx *bootstrap.Context,
	exampleService *service.ExampleService,
) (*kratosHTTP.Server, func(), error) {
	logger := ctx.NewLoggerHelper("template/http")
	listener, err := net.Listen("tcp", httpListenAddr())
	if err != nil {
		return nil, nil, fmt.Errorf("listen module HTTP server: %w", err)
	}

	// 显式使用 Listener 的真实地址，避免 Kratos 把 127.0.0.1 推断成不可达的局域网 IP。
	endpoint := &url.URL{Scheme: "http", Host: listener.Addr().String()}
	server := kratosHTTP.NewServer(
		kratosHTTP.Listener(listener),
		kratosHTTP.Endpoint(endpoint),
	)
	route := server.Route("/")

	var removeRuntimeEndpoint func()
	// 独立模式方便脱离 Core 调试接口，但不会经过 Core 的统一代理与鉴权链路。
	if os.Getenv("MODULE_STANDALONE") == "1" {
		domainpb.RegisterExampleServiceHTTPServer(server, exampleService)

		removeRuntimeEndpoint, err = publishRuntimeEndpoint(endpoint.String())
		if err != nil {
			_ = listener.Close()
			return nil, nil, err
		}
		logger.Warn("standalone HTTP API enabled without Core proxy")
	}

	// 健康检查供容器编排和服务监控判断进程是否可访问。
	route.GET("/health", func(ctx kratosHTTP.Context) error {
		return ctx.JSON(http.StatusOK, map[string]string{"status": "ok"})
	})
	// 下列注册资源也通过 HTTP 暴露，便于 Core 或开发工具按需获取。
	route.GET("/openapi.yaml", func(ctx kratosHTTP.Context) error {
		ctx.Response().Header().Set("Content-Type", "application/yaml")
		_, err := ctx.Response().Write(assets.OpenAPIData)
		return err
	})
	route.GET("/proto-descriptor", func(ctx kratosHTTP.Context) error {
		ctx.Response().Header().Set("Content-Type", "application/octet-stream")
		ctx.Response().Header().Set("Content-Disposition", "attachment; filename=descriptor.bin")
		_, err := ctx.Response().Write(assets.DescriptorData)
		return err
	})
	route.GET("/menus.yaml", func(ctx kratosHTTP.Context) error {
		ctx.Response().Header().Set("Content-Type", "application/yaml")
		_, err := ctx.Response().Write(assets.MenusData)
		return err
	})

	// 去掉嵌入文件系统的顶层目录，使前端产物能够从根路径直接访问。
	frontend, err := fs.Sub(assets.FrontendDist, "frontend-dist")
	if err == nil {
		server.HandlePrefix("/", http.FileServer(http.FS(frontend)))
		logger.Info("serving embedded frontend assets")
	} else {
		logger.Warnf("load embedded frontend assets: %v", err)
	}

	logger.Infof("HTTP server reserved at %s", listener.Addr().String())
	cleanup := func() {
		if removeRuntimeEndpoint != nil {
			removeRuntimeEndpoint()
		}
		_ = listener.Close()
	}
	return server, cleanup, nil
}

// httpListenAddr 返回显式配置的监听地址；未配置时使用端口 0 请求系统分配空闲端口。
func httpListenAddr() string {
	if addr := os.Getenv("MODULE_HTTP_ADDR"); addr != "" {
		return addr
	}
	return defaultHTTPListenAddr
}

// publishRuntimeEndpoint 把 standalone 后端的真实地址写入运行时文件，供 Vite 代理读取。
// 返回的清理函数只删除仍由当前进程写入的内容，避免旧进程误删新进程的地址。
func publishRuntimeEndpoint(endpoint string) (func(), error) {
	runtimeDir, err := moduleRuntimeDir()
	if err != nil {
		return nil, err
	}
	if err = os.MkdirAll(runtimeDir, 0o755); err != nil {
		return nil, fmt.Errorf("create module runtime directory: %w", err)
	}

	path := filepath.Join(runtimeDir, runtimeEndpointFile)
	temporary, err := os.CreateTemp(runtimeDir, ".http-endpoint-*")
	if err != nil {
		return nil, fmt.Errorf("create temporary HTTP endpoint file: %w", err)
	}
	temporaryPath := temporary.Name()
	defer func() { _ = os.Remove(temporaryPath) }()

	if _, err = temporary.WriteString(endpoint + "\n"); err != nil {
		_ = temporary.Close()
		return nil, fmt.Errorf("write HTTP endpoint file: %w", err)
	}
	if err = temporary.Close(); err != nil {
		return nil, fmt.Errorf("close HTTP endpoint file: %w", err)
	}
	if err = os.Rename(temporaryPath, path); err != nil {
		// Windows 不能用 Rename 原子覆盖现有文件；删除崩溃遗留文件后重试。
		if removeErr := os.Remove(path); removeErr != nil && !os.IsNotExist(removeErr) {
			return nil, fmt.Errorf("remove stale HTTP endpoint file: %w", removeErr)
		}
		if err = os.Rename(temporaryPath, path); err != nil {
			return nil, fmt.Errorf("publish HTTP endpoint file: %w", err)
		}
	}

	cleanup := func() {
		current, readErr := os.ReadFile(path)
		if readErr == nil && strings.TrimSpace(string(current)) == endpoint {
			_ = os.Remove(path)
			// 仅当运行时目录为空时一并删除；存在其他进程文件时保持目录不变。
			_ = os.Remove(filepath.Dir(path))
		}
	}
	return cleanup, nil
}

// moduleRuntimeDir 优先使用 MODULE_RUNTIME_DIR；本地开发时默认定位仓库根目录下的 .runtime。
func moduleRuntimeDir() (string, error) {
	configured := os.Getenv("MODULE_RUNTIME_DIR")
	if filepath.IsAbs(configured) {
		return filepath.Clean(configured), nil
	}

	current, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("get working directory: %w", err)
	}
	for {
		if _, statErr := os.Stat(filepath.Join(current, "go.mod")); statErr == nil {
			if configured != "" {
				return filepath.Join(current, configured), nil
			}
			return filepath.Join(current, ".runtime"), nil
		}
		parent := filepath.Dir(current)
		if parent == current {
			return "", fmt.Errorf("locate project root for runtime endpoint file")
		}
		current = parent
	}
}
