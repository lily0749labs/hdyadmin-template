//go:build wireinject
// +build wireinject

// Package providers 声明业务服务层的 Wire 依赖提供者集合。
package providers

import (
	"github.com/google/wire"

	"github.com/neo-fork-gotangra/hdyadmin-template/app/admin/internal/service"
)

// ProviderSet 汇总业务服务构造函数，供应用入口的 Wire 依赖图引用。
var ProviderSet = wire.NewSet(
	service.NewExampleService,
)
