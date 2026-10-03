//go:build wireinject
// +build wireinject

package main

import (
	"github.com/go-kratos/kratos/v2"
	"github.com/google/wire"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	serverProviders "github.com/lily0749labs/hdyadmin-template/app/admin/internal/server/providers"
	serviceProviders "github.com/lily0749labs/hdyadmin-template/app/admin/internal/service/providers"
)

// initApp 描述应用的最小依赖图；新增 Repo、Service 或 Server 后需更新对应 ProviderSet，
// 再执行 make wire 生成实际运行时使用的 wire_gen.go。
func initApp(*bootstrap.Context) (*kratos.App, func(), error) {
	panic(wire.Build(
		serviceProviders.ProviderSet,
		serverProviders.ProviderSet,
		newApp,
	))
}
