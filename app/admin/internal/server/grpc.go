// Package server 负责创建模块的 gRPC、HTTP 服务及传输层中间件。
package server

import (
	"fmt"

	"github.com/go-kratos/kratos/v2/middleware"
	"github.com/go-kratos/kratos/v2/middleware/logging"
	"github.com/go-kratos/kratos/v2/middleware/metadata"
	"github.com/go-kratos/kratos/v2/middleware/recovery"
	"github.com/go-kratos/kratos/v2/middleware/tracing"
	"github.com/go-kratos/kratos/v2/transport/grpc"
	"github.com/go-tangra/go-tangra-common/middleware/mtls"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	domainpb "github.com/lily0749labs/hdyadmin-template/api/pb/domain"
	"github.com/lily0749labs/hdyadmin-template/app/admin/internal/security/cert"
	"github.com/lily0749labs/hdyadmin-template/app/admin/internal/service"
)

// NewGRPCServer 根据应用配置创建 gRPC 服务，装配通用中间件、mTLS 和业务实现。
func NewGRPCServer(
	ctx *bootstrap.Context,
	certManager *cert.CertManager,
	exampleService *service.ExampleService,
) (*grpc.Server, error) {
	cfg := ctx.GetConfig()
	logger := ctx.NewLoggerHelper("template/grpc")

	// 只覆盖配置中显式给出的值，其余选项沿用 Kratos 默认行为。
	var options []grpc.ServerOption
	if cfg.Server != nil && cfg.Server.Grpc != nil {
		if cfg.Server.Grpc.Network != "" {
			options = append(options, grpc.Network(cfg.Server.Grpc.Network))
		}
		if cfg.Server.Grpc.Addr != "" {
			options = append(options, grpc.Address(cfg.Server.Grpc.Addr))
		}
		if cfg.Server.Grpc.Timeout != nil {
			options = append(options, grpc.Timeout(cfg.Server.Grpc.Timeout.AsDuration()))
		}
	}

	// 中间件按声明顺序包裹处理器，统一提供恢复、追踪、元数据和访问日志能力。
	middlewares := []middleware.Middleware{
		recovery.Recovery(),
		tracing.Server(),
		metadata.Server(),
		logging.Server(ctx.GetLogger()),
	}

	if certManager != nil && certManager.IsTLSEnabled() {
		tlsConfig, err := certManager.GetServerTLSConfig()
		if err != nil {
			return nil, fmt.Errorf("load module mTLS config: %w", err)
		}
		options = append(options, grpc.TLSConfig(tlsConfig))
		// 健康检查需要在注册和探活阶段可访问，其余 RPC 均校验客户端证书。
		middlewares = append(middlewares, mtls.MTLSMiddleware(
			ctx.GetLogger(),
			mtls.WithPublicEndpoints(
				"/grpc.health.v1.Health/Check",
				"/grpc.health.v1.Health/Watch",
			),
		))
		logger.Info("gRPC server configured with mTLS")
	} else {
		logger.Warn("gRPC server is running without mTLS")
	}

	// 业务处理前执行 Proto 约束校验，并把校验失败统一映射为 400 错误。
	middlewares = append(middlewares, protoValidator())
	options = append(options, grpc.Middleware(middlewares...))

	server := grpc.NewServer(options...)
	// 使用脱敏包装器注册服务，避免敏感字段直接出现在日志中。
	domainpb.RegisterRedactedExampleServiceServer(server, exampleService, nil)
	return server, nil
}
