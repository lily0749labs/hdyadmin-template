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

	"github.com/neo-fork-gotangra/hdyadmin-template/app/internal/security/cert"
	"github.com/neo-fork-gotangra/hdyadmin-template/app/internal/service"
	domainpb "github.com/neo-fork-gotangra/hdyadmin-template/api/pb/domain"
)

func NewGRPCServer(
	ctx *bootstrap.Context,
	certManager *cert.CertManager,
	exampleService *service.ExampleService,
) (*grpc.Server, error) {
	cfg := ctx.GetConfig()
	logger := ctx.NewLoggerHelper("template/grpc")

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

	middlewares = append(middlewares, protoValidator())
	options = append(options, grpc.Middleware(middlewares...))

	server := grpc.NewServer(options...)
	domainpb.RegisterRedactedExampleServiceServer(server, exampleService, nil)
	return server, nil
}
