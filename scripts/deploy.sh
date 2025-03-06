#!/bin/bash

# 设置环境变量
export $(cat .env | xargs)

# 构建 Docker 镜像
docker-compose build

# 推送到 AWS ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker tag app:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/app:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/app:latest

# 更新 ECS 服务
aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment 