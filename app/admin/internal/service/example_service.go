// Package service 包含模块的应用服务与业务用例实现。
package service

import (
	"context"
	"fmt"

	"github.com/tx7do/kratos-bootstrap/bootstrap"

	domainpb "github.com/neo-fork-gotangra/hdyadmin-template/api/pb/domain"
)

// ExampleService 实现 Proto 定义的示例服务，用于验证模块注册和端到端调用链路。
type ExampleService struct {
	// 嵌入默认实现可在 Proto 新增 RPC 时保持向前兼容。
	domainpb.UnimplementedExampleServiceServer
}

// NewExampleService 创建无状态的示例服务；保留 Bootstrap 上下文参数便于后续注入依赖。
func NewExampleService(_ *bootstrap.Context) *ExampleService {
	return &ExampleService{}
}

// SayHello 返回包含请求名称的问候语。
func (s *ExampleService) SayHello(_ context.Context, req *domainpb.SayHelloRequest) (*domainpb.SayHelloResponse, error) {
	return &domainpb.SayHelloResponse{
		Message: fmt.Sprintf("Hello %s, hdyadmin module is ready.", req.GetName()),
	}, nil
}
