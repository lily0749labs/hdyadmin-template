// Package service contains the module's application services.
package service

import (
	"context"
	"fmt"

	"github.com/tx7do/kratos-bootstrap/bootstrap"

	domainpb "github.com/neo-fork-gotangra/hdyadmin-template/api/pb/domain"
)

type ExampleService struct {
	domainpb.UnimplementedExampleServiceServer
}

func NewExampleService(_ *bootstrap.Context) *ExampleService {
	return &ExampleService{}
}

func (s *ExampleService) SayHello(_ context.Context, req *domainpb.SayHelloRequest) (*domainpb.SayHelloResponse, error) {
	return &domainpb.SayHelloResponse{
		Message: fmt.Sprintf("Hello %s, hdyadmin module is ready.", req.GetName()),
	}, nil
}
