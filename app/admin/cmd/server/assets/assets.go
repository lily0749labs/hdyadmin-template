// Package assets 保存编译进模块服务的注册资源和远程前端文件。
package assets

import (
	"embed"
	_ "embed"
)

// OpenAPIData 是向 Core 注册并通过 HTTP 暴露的 OpenAPI 文档。
//
//go:embed openapi.yaml
var OpenAPIData []byte

// MenusData 是模块的菜单、权限组和默认角色定义。
//
//go:embed menus.yaml
var MenusData []byte

// DescriptorData 是供 Core 动态发现和代理 gRPC 服务使用的 Proto 描述符。
//
//go:embed descriptor.bin
var DescriptorData []byte

// FrontendDist 保存随服务端二进制发布的远程前端静态资源。
//
//go:embed all:frontend-dist
var FrontendDist embed.FS
