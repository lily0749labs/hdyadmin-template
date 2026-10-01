//go:build wireinject
// +build wireinject

package providers

import (
	"github.com/google/wire"

	"github.com/neo-fork-gotangra/hdyadmin-template/app/admin/internal/security/cert"
	"github.com/neo-fork-gotangra/hdyadmin-template/app/admin/internal/server"
)

var ProviderSet = wire.NewSet(
	cert.NewCertManager,
	server.NewGRPCServer,
	server.NewHTTPServer,
)
