# 使用多阶段构建
FROM debian:latest AS builder

# 安装依赖
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils

# 安装 Flutter SDK
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:${PATH}"
RUN flutter doctor

# 复制项目文件
COPY . /app/
WORKDIR /app

# 获取依赖并构建
RUN flutter pub get
RUN flutter build web --release

# 生产环境镜像
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html

# 复制 nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 环境变量配置
ENV ENVIRONMENT=production

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost/ || exit 1

# 暴露端口
EXPOSE 80

# 启动 nginx
CMD ["nginx", "-g", "daemon off;"] 