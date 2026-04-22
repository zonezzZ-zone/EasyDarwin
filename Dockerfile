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

# 1. 拷贝二进制
COPY --from=builder /app/easydarwin /app/easydarwin

# 2. 拷贝配置文件
RUN mkdir -p /app/configs
COPY configs/ /app/configs/

# 3. 【核心新增】拷贝前端网页文件夹
# 这一步非常重要，没有它就没有后台界面
COPY web/ /app/web/ 

# 4. 配置对齐（双重保险）
RUN cp /app/configs/config.toml /app/easydarwin.toml && \
    cp /app/configs/config.toml /app/config.toml

EXPOSE 10086 10035 10054 10010/udp
RUN chmod +x easydarwin

# 5. 启动
ENTRYPOINT ["/app/easydarwin", "-conf", "/app/easydarwin.toml"]
