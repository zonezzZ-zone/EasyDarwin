# 第一阶段：编译环境 (Go 1.23)
FROM golang:1.23-alpine AS builder
RUN apk add --no-cache git
WORKDIR /app
COPY . .
# 修复版本时间逻辑
RUN printf 'package main\n\nimport "time"\n\nfunc GetBuildTime() time.Time {\n\treturn time.Date(2026, 4, 21, 0, 0, 0, 0, time.UTC)\n}\n\nfunc GetVersion() string {\n\treturn "v8.3.3"\n}\n' > cmd/server/version.go
ENV GOPROXY=https://goproxy.cn,direct
RUN go mod tidy && go build -o easydarwin ./cmd/server

# 第二阶段：运行环境
FROM alpine:latest
RUN apk add --no-cache libc6-compat ca-certificates tzdata
ENV TZ=Asia/Shanghai
WORKDIR /app

# 1. 拷贝二进制文件
COPY --from=builder /app/easydarwin /app/easydarwin

# 2. 【核心优化】直接搬运仓库里真实的 configs 目录
# 这一步会自动把你的 key.pem, cert.pem, config.toml 全部带进去
RUN mkdir -p /app/configs
COPY configs/ /app/configs/

# 3. 【配置对齐】把配置改名为 easydarwin.toml，放满所有可能的位置
# 确保程序无论怎么找都能撞上你那份带 MySQL 地址的配置
RUN cp /app/configs/config.toml /app/easydarwin.toml && \
    cp /app/configs/config.toml /app/config.toml && \
    cp /app/configs/config.toml /app/configs/easydarwin.toml

# 4. 权限检查
RUN chmod +x easydarwin

EXPOSE 10086 10035 10054 10010/udp

# 5. 【最后通牒】强制指定配置文件路径启动
ENTRYPOINT ["/app/easydarwin", "-conf", "/app/easydarwin.toml"]
