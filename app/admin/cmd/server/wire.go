//go:build wireinject
// +build wireinject

package main

import (
	"github.com/go-kratos/kratos/v2"
	"github.com/google/wire"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	serverProviders "github.com/neo-fork-gotangra/hdyadmin-template/app/admin/internal/server/providers"
	serviceProviders "github.com/neo-fork-gotangra/hdyadmin-template/app/admin/internal/service/providers"
)

// initApp 描述最小依赖图；新增 Repo、Service 或 Server 后更新对应 ProviderSet。
func initApp(*bootstrap.Context) (*kratos.App, func(), error) {
	panic(wire.Build(
		serviceProviders.ProviderSet,
		serverProviders.ProviderSet,
		newApp,
	))
}
