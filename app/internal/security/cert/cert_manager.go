// Package cert connects the module to hdyadmin-common's certificate bootstrap flow.
package cert

import (
	"context"
	"os"

	commonCert "github.com/go-tangra/go-tangra-common/cert"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
)

type CertManager = commonCert.CertManager

// NewCertManager provisions mTLS certificates through hdyadmin-lcm.
// MODULE_TLS_DISABLED=1 is intended only for local smoke tests.
func NewCertManager(ctx *bootstrap.Context) (*CertManager, error) {
	if os.Getenv("MODULE_TLS_DISABLED") == "1" {
		return commonCert.NewCertManager(ctx, "TEMPLATE")
	}

	return commonCert.Ensure(context.Background(), commonCert.EnsureConfig{
		ModuleID: "template",
		Logger:   ctx.GetLogger(),
	})
}
