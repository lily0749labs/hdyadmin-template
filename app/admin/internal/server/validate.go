package server

import (
	"context"

	"buf.build/go/protovalidate"
	"github.com/go-kratos/kratos/v2/errors"
	"github.com/go-kratos/kratos/v2/middleware"
	"google.golang.org/protobuf/proto"
)

func protoValidator() middleware.Middleware {
	return func(handler middleware.Handler) middleware.Handler {
		return func(ctx context.Context, req interface{}) (interface{}, error) {
			if message, ok := req.(proto.Message); ok {
				if err := protovalidate.Validate(message); err != nil {
					return nil, errors.BadRequest("VALIDATOR", err.Error())
				}
			}
			return handler(ctx, req)
		}
	}
}
