// Package assets 保存编译进模块服务的注册资源和远程前端。
package assets

import (
	"embed"
	_ "embed"
)

//go:embed openapi.yaml
var OpenAPIData []byte

//go:embed menus.yaml
var MenusData []byte

//go:embed descriptor.bin
var DescriptorData []byte

//go:embed all:frontend-dist
var FrontendDist embed.FS
