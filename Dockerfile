# 第一阶段：编译环境
FROM golang:1.23-alpine AS builder
RUN apk add --no-cache git
WORKDIR /app
COPY . .
RUN printf 'package main\n\nimport "time"\n\nfunc GetBuildTime() time.Time {\n\treturn time.Date(2026, 4, 21, 0, 0, 0, 0, time.UTC)\n}\n\nfunc GetVersion() string {\n\treturn "v8.3.3"\n}\n' > cmd/server/version.go
ENV GOPROXY=https://goproxy.cn,direct
RUN go mod tidy && go build -o easydarwin ./cmd/server

# 第二阶段：运行环境
FROM alpine:latest
RUN apk add --no-cache libc6-compat ca-certificates tzdata
ENV TZ=Asia/Shanghai
WORKDIR /app

# 1. 拷贝二进制
COPY --from=builder /app/easydarwin /app/easydarwin

# 2. 【核心修改】把配置改名为 easydarwin.toml，并放到程序根目录
# EasyDarwin 默认会找跟二进制文件同名的 .toml 文件
COPY configs/config.toml /app/easydarwin.toml
COPY configs/config.toml /app/config.toml

# 3. 同时在子目录下也存一份，防止它乱跳
RUN mkdir -p /app/configs
COPY configs/config.toml /app/configs/easydarwin.toml
COPY configs/config.toml /app/configs/config.toml

EXPOSE 10086 10035 10054 10010/udp
RUN chmod +x easydarwin

# 4. 【终极指令】不再加那些可能无效的参数，直接启动
# 程序会自动在当前目录找 easydarwin.toml
ENTRYPOINT ["./easydarwin"]
