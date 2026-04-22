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

# 2. 【核心修改】把配置改名为 easydarwin.toml，放满所有可能的位置
# 确保它怎么找都能撞上这一份
RUN mkdir -p /app/configs
COPY configs/config.toml /app/easydarwin.toml
COPY configs/config.toml /app/config.toml
COPY configs/config.toml /app/configs/easydarwin.toml
COPY configs/config.toml /app/configs/config.toml

# 3. 补充它一直报错要找的证书占位（防止它因为找不到文件而 Panic）
# 删掉之前的 touch /app/configs/cert.pem ...
# 改为下面这两行（这是合法的 PEM 头尾，虽然内容是假的，但能过解析器的初审）
RUN mkdir -p /app/configs && \
    printf -- "-----BEGIN CERTIFICATE-----\nMIICWDCCAcGgAwIBAgIJAP9Z\n-----END CERTIFICATE-----" > /app/configs/cert.pem && \
    printf -- "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA75\n-----END RSA PRIVATE KEY-----" > /app/configs/key.pem

EXPOSE 10086 10035 10054 10010/udp
RUN chmod +x easydarwin

# 4. 【最后通牒】强制指定配置文件路径启动
ENTRYPOINT ["/app/easydarwin", "-conf", "/app/easydarwin.toml"]
