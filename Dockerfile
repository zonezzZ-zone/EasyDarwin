# 第一阶段：编译环境 (Go 1.23)
FROM golang:1.23-alpine AS builder

# 安装编译必需工具
RUN apk add --no-cache git

# 设置工作目录
WORKDIR /app

# --- 核心修改点 1：不再去拉取 Git，直接复制你本地修改好的代码 ---
# 这会把宿主机当前目录下的 configs/、cmd/、go.mod 等全部拷进去
COPY . .

# 核心修复点：修复版本时间（保持你之前的逻辑）
RUN printf 'package main\n\nimport "time"\n\nfunc GetBuildTime() time.Time {\n\treturn time.Date(2026, 4, 21, 0, 0, 0, 0, time.UTC)\n}\n\nfunc GetVersion() string {\n\treturn "v8.3.3"\n}\n' > cmd/server/version.go

# 设置国内代理并编译
ENV GOPROXY=https://goproxy.cn,direct
RUN go mod tidy && \
    go build -o easydarwin ./cmd/server

# 第二阶段：运行环境
FROM alpine:latest

# 增加兼容库和时区支持
RUN apk add --no-cache libc6-compat ca-certificates tzdata
ENV TZ=Asia/Shanghai

WORKDIR /app

# 从 builder 阶段拷贝生成的二进制文件
COPY --from=builder /app/easydarwin /app/easydarwin

# --- 核心修改点 2：将配置文件夹完整拷贝到容器指定目录 ---
# 这样镜像里就有了 /app/configs/config.toml，不再依赖宿主机挂载
COPY --from=builder /app/configs /app/configs

# 暴露端口
EXPOSE 10086 10035 10054 10010/udp

# 赋予权限
RUN chmod +x easydarwin

# --- 核心修改点 3：启动时显式指定配置文件路径 ---
# 不让程序自己乱找，直接喂到它嘴里
ENTRYPOINT ["./easydarwin", "-conf", "/app/configs/config.toml"]
