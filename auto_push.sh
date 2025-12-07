#!/bin/bash

# 自动推送到GitHub的脚本
# 使用方法: ./auto_push.sh "你的提交信息"
# 或者: ./auto_push.sh (使用默认提交信息)

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 获取提交信息
if [ -z "$1" ]; then
    # 如果没有提供提交信息,使用默认的带时间戳的信息
    COMMIT_MSG="Update: $(date '+%Y-%m-%d %H:%M:%S')"
else
    COMMIT_MSG="$1"
fi

echo -e "${YELLOW}开始自动推送到GitHub...${NC}\n"

# 检查是否在git仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}错误: 当前目录不是git仓库${NC}"
    exit 1
fi

# 显示当前状态
echo -e "${YELLOW}当前git状态:${NC}"
git status
echo ""

# 添加所有更改
echo -e "${YELLOW}添加所有更改...${NC}"
git add .

if [ $? -ne 0 ]; then
    echo -e "${RED}错误: git add 失败${NC}"
    exit 1
fi

# 检查是否有更改需要提交
if git diff --staged --quiet; then
    echo -e "${YELLOW}没有需要提交的更改${NC}"
else
    # 提交更改
    echo -e "${YELLOW}提交更改...${NC}"
    echo -e "提交信息: ${GREEN}$COMMIT_MSG${NC}"
    git commit -m "$COMMIT_MSG"

    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: git commit 失败${NC}"
        exit 1
    fi
fi

# 推送到远程仓库
echo -e "${YELLOW}推送到远程仓库...${NC}"
git push origin $(git branch --show-current)

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ 成功推送到GitHub!${NC}"
else
    echo -e "\n${RED}✗ 推送失败,请检查网络连接或权限${NC}"
    exit 1
fi
