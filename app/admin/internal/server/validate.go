package server

import (
	"context"

	"buf.build/go/protovalidate"
	"github.com/go-kratos/kratos/v2/errors"
	"github.com/go-kratos/kratos/v2/middleware"
	"google.golang.org/protobuf/proto"
)

// protoValidator 创建基于 Proto 字段约束的请求校验中间件。
func protoValidator() middleware.Middleware {
	return func(handler middleware.Handler) middleware.Handler {
		return func(ctx context.Context, req interface{}) (interface{}, error) {
			// 仅 Proto 消息带有 protovalidate 规则；其他请求类型直接交给后续处理器。
			if message, ok := req.(proto.Message); ok {
				if err := protovalidate.Validate(message); err != nil {
					// 使用稳定的错误原因码，便于客户端区分参数错误与服务端故障。
					return nil, errors.BadRequest("VALIDATOR", err.Error())
				}
			}
			return handler(ctx, req)
		}
	}
}
