#!/bin/bash

# 检查是否提供了任务文件参数
if [ $# -eq 0 ]; then
    echo "用法: $0 <任务文件> [延时秒数] [初始session_id]"
    echo "任务文件格式: 每行一个任务"
    echo "延时秒数: 可选，每个任务执行完后等待的秒数，默认5秒"
    echo "初始session_id: 可选，如果提供则从该session继续"
    exit 1
fi

TASK_FILE="$1"
DELAY_SECONDS="${2:-5}"  # 默认延时5秒
CURRENT_SESSION_ID="$3"  # 可选的session_id

# 检查任务文件是否存在
if [ ! -f "$TASK_FILE" ]; then
    echo "错误: 任务文件 '$TASK_FILE' 不存在"
    exit 1
fi

# 创建输出文件保存session_id
OUTPUT_FILE="session_ids_$(date +%Y%m%d_%H%M%S).txt"
LOG_FILE="task_execution_$(date +%Y%m%d_%H%M%S).log"

echo "开始处理任务..."
echo "输出文件: $OUTPUT_FILE"
echo "日志文件: $LOG_FILE"
if [ -n "$CURRENT_SESSION_ID" ]; then
    echo "初始Session ID: $CURRENT_SESSION_ID"
fi
echo "任务间延时: $DELAY_SECONDS 秒"
echo "-----------------------------------"

# 任务计数器
TASK_COUNT=0
SUCCESS_COUNT=0
FAIL_COUNT=0

# 读取任务文件并逐行处理
while IFS= read -r task || [ -n "$task" ]; do
    # 跳过空行和注释行
    if [ -z "$task" ] || [[ "$task" =~ ^[[:space:]]*# ]]; then
        echo "[跳过] 空行或注释" >> "$LOG_FILE"
        continue
    fi

    TASK_COUNT=$((TASK_COUNT + 1))

    echo "" | tee -a "$LOG_FILE"
    echo "====================================" | tee -a "$LOG_FILE"
    echo "任务 #$TASK_COUNT: $task" | tee -a "$LOG_FILE"
    echo "====================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # 执行claude命令并提取session_id
    if [ -n "$CURRENT_SESSION_ID" ]; then
        # 使用上一次的session_id继续
        echo ">>> 使用上一次的 Session ID: $CURRENT_SESSION_ID" | tee -a "$LOG_FILE"
        echo ">>> 正在执行 claude 命令，请稍候..." | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        # 将claude的完整输出保存到临时文件
        TEMP_OUTPUT=$(mktemp)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行: claude -p --resume $CURRENT_SESSION_ID \"$task\"" >> "$LOG_FILE"

        claude -p --resume "$CURRENT_SESSION_ID" "$task" --dangerously-skip-permissions --output-format json < /dev/null > "$TEMP_OUTPUT" 2>&1
        EXIT_CODE=$?

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 退出码: $EXIT_CODE" >> "$LOG_FILE"
        cat "$TEMP_OUTPUT" >> "$LOG_FILE"

        # 解析并显示结果
        session_id=$(cat "$TEMP_OUTPUT" | jq -r '.session_id' 2>/dev/null)
        result_text=$(cat "$TEMP_OUTPUT" | jq -r '.result' 2>/dev/null)
        is_error=$(cat "$TEMP_OUTPUT" | jq -r '.is_error' 2>/dev/null)

        # 显示执行结果
        echo ""
        echo "--- Claude 执行结果 ---"
        if [ "$is_error" = "true" ]; then
            echo "❌ 错误:"
        fi
        if [ -n "$result_text" ] && [ "$result_text" != "null" ]; then
            echo "$result_text"
        else
            # 如果没有 result 字段，显示原始输出
            cat "$TEMP_OUTPUT"
        fi
        echo "--- 结果结束 ---"
        echo ""
    else
        # 第一次执行，不使用--resume参数
        echo ">>> 首次执行，创建新会话" | tee -a "$LOG_FILE"
        echo ">>> 正在执行 claude 命令，请稍候..." | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        # 将claude的完整输出保存到临时文件
        TEMP_OUTPUT=$(mktemp)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行: claude -p \"$task\"" >> "$LOG_FILE"

        claude -p "$task" --dangerously-skip-permissions --output-format json < /dev/null > "$TEMP_OUTPUT" 2>&1
        EXIT_CODE=$?

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 退出码: $EXIT_CODE" >> "$LOG_FILE"
        cat "$TEMP_OUTPUT" >> "$LOG_FILE"

        # 解析并显示结果
        session_id=$(cat "$TEMP_OUTPUT" | jq -r '.session_id' 2>/dev/null)
        result_text=$(cat "$TEMP_OUTPUT" | jq -r '.result' 2>/dev/null)
        is_error=$(cat "$TEMP_OUTPUT" | jq -r '.is_error' 2>/dev/null)

        # 显示执行结果
        echo ""
        echo "--- Claude 执行结果 ---"
        if [ "$is_error" = "true" ]; then
            echo "❌ 错误:"
        fi
        if [ -n "$result_text" ] && [ "$result_text" != "null" ]; then
            echo "$result_text"
        else
            # 如果没有 result 字段，显示原始输出
            cat "$TEMP_OUTPUT"
        fi
        echo "--- 结果结束 ---"
        echo ""
    fi

    # 清理临时文件
    rm -f "$TEMP_OUTPUT"

    echo "" | tee -a "$LOG_FILE"
    echo "====================================" | tee -a "$LOG_FILE"
    if [ -n "$session_id" ] && [ "$session_id" != "null" ]; then
        echo "✓ 任务 #$TASK_COUNT 完成" | tee -a "$LOG_FILE"
        echo "✓ 本次任务的 Session ID: $session_id" | tee -a "$LOG_FILE"
        echo "$task|$session_id" >> "$OUTPUT_FILE"
        # 更新当前session_id供下一次使用
        CURRENT_SESSION_ID="$session_id"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "✗ 任务 #$TASK_COUNT 失败或未返回session_id" | tee -a "$LOG_FILE"
        echo "✗ 将继续执行下一个任务..." | tee -a "$LOG_FILE"
        echo "$task|ERROR" >> "$OUTPUT_FILE"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        # 如果失败，保持之前的session_id继续下一个任务
    fi
    echo "====================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # 延时等待（除了最后一个任务，但为了简化逻辑，每个任务后都延时）
    if [ $DELAY_SECONDS -gt 0 ]; then
        echo "⏱️  等待 $DELAY_SECONDS 秒后执行下一个任务..." | tee -a "$LOG_FILE"
        for ((i=$DELAY_SECONDS; i>0; i--)); do
            printf "\r倒计时: %d 秒... " $i
            sleep 1
        done
        printf "\r✓ 等待完成，继续执行          \n"
        echo "" | tee -a "$LOG_FILE"
    fi

done < "$TASK_FILE"

echo ""
echo "==========================================" | tee -a "$LOG_FILE"
echo "所有任务处理完成!" | tee -a "$LOG_FILE"
echo "总任务数: $TASK_COUNT" | tee -a "$LOG_FILE"
echo "成功: $SUCCESS_COUNT" | tee -a "$LOG_FILE"
echo "失败: $FAIL_COUNT" | tee -a "$LOG_FILE"
echo "最终Session ID: $CURRENT_SESSION_ID" | tee -a "$LOG_FILE"
echo "结果已保存到: $OUTPUT_FILE" | tee -a "$LOG_FILE"
echo "详细日志: $LOG_FILE" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"
