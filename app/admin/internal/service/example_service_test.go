package service

import (
	"context"
	"testing"

	domainpb "github.com/neo-fork-gotangra/hdyadmin-template/api/pb/domain"
)

func TestExampleServiceSayHello(t *testing.T) {
	service := &ExampleService{}
	response, err := service.SayHello(context.Background(), &domainpb.SayHelloRequest{Name: "Codex"})
	if err != nil {
		t.Fatalf("SayHello() error = %v", err)
	}
	if got, want := response.GetMessage(), "Hello Codex, hdyadmin module is ready."; got != want {
		t.Fatalf("SayHello() message = %q, want %q", got, want)
	}
}
