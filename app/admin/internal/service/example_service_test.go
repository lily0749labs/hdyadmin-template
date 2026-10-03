package service

import (
	"context"
	"testing"

	domainpb "github.com/neo-fork-gotangra/hdyadmin-template/api/pb/domain"
)

func TestExampleServiceSayHello(t *testing.T) {
	// 该服务当前无外部依赖，可直接构造并验证返回内容。
	service := &ExampleService{}
	response, err := service.SayHello(context.Background(), &domainpb.SayHelloRequest{Name: "Codex"})
	if err != nil {
		t.Fatalf("SayHello() error = %v", err)
	}
	if got, want := response.GetMessage(), "Hello Codex, hdyadmin module is ready."; got != want {
		t.Fatalf("SayHello() message = %q, want %q", got, want)
	}
}
