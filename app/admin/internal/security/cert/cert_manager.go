// Package cert 封装模块接入 hdyadmin 公共证书初始化流程所需的依赖。
package cert

import (
	"context"
	"os"

	commonCert "github.com/go-tangra/go-tangra-common/cert"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
)

// CertManager 是公共证书管理器的别名，负责保存证书并生成服务端 TLS 配置。
type CertManager = commonCert.CertManager

// NewCertManager 通过 hdyadmin-lcm 申请或加载模块的 mTLS 证书。
// 当 MODULE_TLS_DISABLED=1 时返回空管理器，使 gRPC 以无 TLS 模式启动；
// 该开关仅供本地冒烟测试使用，不应在生产环境启用。
func NewCertManager(ctx *bootstrap.Context) (*CertManager, error) {
	if os.Getenv("MODULE_TLS_DISABLED") == "1" {
		return nil, nil
	}

	return commonCert.Ensure(context.Background(), commonCert.EnsureConfig{
		ModuleID: "template",
		Logger:   ctx.GetLogger(),
	})
}
