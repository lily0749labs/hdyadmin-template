// hdyadmin 独立业务模块启动入口。
package main

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2"
	"github.com/go-kratos/kratos/v2/transport/grpc"
	kratosHTTP "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	conf "github.com/tx7do/kratos-bootstrap/api/gen/go/conf/v1"

	"github.com/go-tangra/go-tangra-common/registration"
	commonService "github.com/go-tangra/go-tangra-common/service"
	"github.com/neo-fork-gotangra/hdyadmin-template/app/cmd/server/assets"
)

var (
	// 这些模板值会由 scripts/new-module.sh 统一替换。
	moduleID    = "template"
	moduleName  = "Template"
	version     = "1.0.0"
	description = "Starter module for hdyadmin"
)

var globalRegistration *registration.RegistrationHelper

func newApp(
	ctx *bootstrap.Context,
	gs *grpc.Server,
	hs *kratosHTTP.Server,
) *kratos.App {
	globalRegistration = registration.StartRegistration(ctx, ctx.GetLogger(), &registration.Config{
		ModuleID:          moduleID,
		ModuleName:        moduleName,
		Version:           version,
		Description:       description,
		GRPCEndpoint:      registration.GetGRPCAdvertiseAddr(ctx, "127.0.0.1:10400"),
		FrontendEntryUrl:  registration.GetEnvOrDefault("FRONTEND_ENTRY_URL", ""),
		HttpEndpoint:      registration.GetEnvOrDefault("HTTP_ADVERTISE_ADDR", ""),
		AdminEndpoint:     registration.GetEnvOrDefault("ADMIN_GRPC_ENDPOINT", ""),
		OpenapiSpec:       assets.OpenAPIData,
		ProtoDescriptor:   assets.DescriptorData,
		MenusYaml:         assets.MenusData,
		HeartbeatInterval: 30 * time.Second,
		RetryInterval:     5 * time.Second,
		MaxRetries:        60,
	})

	return bootstrap.NewApp(ctx, gs, hs)
}

func runApp() error {
	ctx := bootstrap.NewContext(
		context.Background(),
		&conf.AppInfo{
			Project: commonService.Project,
			AppId:   "hdyadmin.template.service",
			Name:    moduleName,
			Version: version,
		},
	)

	defer func() {
		if globalRegistration != nil {
			globalRegistration.Stop()
		}
	}()

	return bootstrap.RunApp(ctx, initApp)
}

func main() {
	if err := runApp(); err != nil {
		panic(err)
	}
}
