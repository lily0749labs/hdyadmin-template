// Package main 是 hdyadmin 模板模块的进程启动入口。
package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/go-kratos/kratos/v2"
	"github.com/go-kratos/kratos/v2/transport/grpc"
	kratosHTTP "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	conf "github.com/tx7do/kratos-bootstrap/api/gen/go/conf/v1"

	"github.com/go-tangra/go-tangra-common/registration"
	commonService "github.com/go-tangra/go-tangra-common/service"
	"github.com/lily0749labs/hdyadmin-template/app/admin/cmd/server/assets"
)

var (
	// 创建新业务模块时需要同步修改这些元数据以及 assets/menus.yaml。
	moduleID    = "template"
	moduleName  = "Template"
	version     = "1.0.0"
	description = "Template module for hdyadmin"
)

// globalRegistration 保存模块注册与心跳任务，以便进程退出时主动停止。
var globalRegistration *registration.RegistrationHelper

// newApp 启动模块注册，并把已构造的 gRPC、HTTP 服务装配到 Kratos 应用中。
func newApp(
	ctx *bootstrap.Context,
	gs *grpc.Server,
	hs *kratosHTTP.Server,
) (*kratos.App, error) {
	// 未显式配置对外 HTTP 地址时，使用服务器已经绑定的真实随机端口。
	httpEndpoint := registration.GetEnvOrDefault("HTTP_ADVERTISE_ADDR", "")
	if httpEndpoint == "" {
		endpoint, err := hs.Endpoint()
		if err != nil {
			return nil, fmt.Errorf("resolve HTTP advertise endpoint: %w", err)
		}
		httpEndpoint = endpoint.Host
	}

	// 注册信息供 Core 发现本模块、建立动态代理并创建菜单与权限。
	globalRegistration = registration.StartRegistration(ctx, ctx.GetLogger(), &registration.Config{
		ModuleID:          moduleID,
		ModuleName:        moduleName,
		Version:           version,
		Description:       description,
		GRPCEndpoint:      registration.GetGRPCAdvertiseAddr(ctx, "127.0.0.1:10400"),
		FrontendEntryUrl:  registration.GetEnvOrDefault("FRONTEND_ENTRY_URL", ""),
		HttpEndpoint:      httpEndpoint,
		AdminEndpoint:     registration.GetEnvOrDefault("ADMIN_GRPC_ENDPOINT", ""),
		OpenapiSpec:       assets.OpenAPIData,
		ProtoDescriptor:   assets.DescriptorData,
		MenusYaml:         assets.MenusData,
		HeartbeatInterval: 30 * time.Second,
		RetryInterval:     5 * time.Second,
		MaxRetries:        60,
	})

	return bootstrap.NewApp(ctx, gs, hs), nil
}

// runApp 创建应用上下文、执行 Wire 生成的依赖注入函数，并托管完整生命周期。
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
		// 无论正常退出还是启动失败，都停止后台注册与心跳，避免资源泄漏。
		if globalRegistration != nil {
			globalRegistration.Stop()
		}
	}()

	return bootstrap.RunApp(ctx, initApp)
}

// main 将启动错误提升为 panic，使进程以非零状态退出并交由运行环境处理。
func main() {
	// VS Code connected 调试在预启动任务之后由进程加载本地环境文件，
	// 避免调试适配器先读取不存在的 envFile 而直接报 ENOENT。
	if envFile := os.Getenv("MODULE_ENV_FILE"); envFile != "" {
		if err := loadEnvFile(envFile); err != nil {
			panic(err)
		}
	}
	if err := runApp(); err != nil {
		panic(err)
	}
}
