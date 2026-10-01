package server

import (
	"io/fs"
	"net/http"
	"os"

	kratosHTTP "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	"github.com/neo-fork-gotangra/hdyadmin-template/app/admin/cmd/server/assets"
)

// NewHTTPServer serves health checks, registration assets and the embedded remote frontend.
// Business HTTP requests are dynamically proxied by hdyadmin-core to this module's gRPC API.
func NewHTTPServer(ctx *bootstrap.Context) *kratosHTTP.Server {
	logger := ctx.NewLoggerHelper("template/http")
	addr := os.Getenv("MODULE_HTTP_ADDR")
	if addr == "" {
		addr = "127.0.0.1:10401"
	}

	server := kratosHTTP.NewServer(kratosHTTP.Address(addr))
	route := server.Route("/")

	route.GET("/health", func(ctx kratosHTTP.Context) error {
		return ctx.JSON(http.StatusOK, map[string]string{"status": "ok"})
	})
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
