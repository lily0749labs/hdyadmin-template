package server

import (
	"io/fs"
	"net/http"
	"os"

	kratosHTTP "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	domainpb "github.com/neo-fork-gotangra/hdyadmin-template/api/pb/domain"
	"github.com/neo-fork-gotangra/hdyadmin-template/app/admin/cmd/server/assets"
	"github.com/neo-fork-gotangra/hdyadmin-template/app/admin/internal/service"
)

// NewHTTPServer 提供健康检查、模块注册资源和内嵌的远程前端文件。
// 独立运行模式下，它还会开放通常由 Core 转发到 gRPC 的业务 HTTP 路由。
func NewHTTPServer(
	ctx *bootstrap.Context,
	exampleService *service.ExampleService,
) *kratosHTTP.Server {
	logger := ctx.NewLoggerHelper("template/http")
	addr := os.Getenv("MODULE_HTTP_ADDR")
	if addr == "" {
		addr = "127.0.0.1:10401"
	}

	server := kratosHTTP.NewServer(kratosHTTP.Address(addr))
	route := server.Route("/")
	// 独立模式方便脱离 Core 调试接口，但不会经过 Core 的统一代理与鉴权链路。
	if os.Getenv("MODULE_STANDALONE") == "1" {
		domainpb.RegisterExampleServiceHTTPServer(server, exampleService)
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

	logger.Infof("HTTP server listening on %s", addr)
	return server
}
