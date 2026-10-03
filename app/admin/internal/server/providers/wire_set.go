//go:build wireinject
// +build wireinject

// Package providers 声明传输层的 Wire 依赖提供者集合。
package providers

import (
	"github.com/google/wire"

	"github.com/lily0749labs/hdyadmin-template/app/admin/internal/security/cert"
	"github.com/lily0749labs/hdyadmin-template/app/admin/internal/server"
)

// ProviderSet 汇总传输层所需的证书管理器、gRPC 服务和 HTTP 服务构造函数。
var ProviderSet = wire.NewSet(
	cert.NewCertManager,
	server.NewGRPCServer,
	server.NewHTTPServer,
)
