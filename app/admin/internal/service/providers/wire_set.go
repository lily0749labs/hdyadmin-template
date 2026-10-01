//go:build wireinject
// +build wireinject

package providers

import (
	"github.com/google/wire"

	"github.com/neo-fork-gotangra/hdyadmin-template/app/admin/internal/service"
)

var ProviderSet = wire.NewSet(
	service.NewExampleService,
)
