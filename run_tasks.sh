#!/bin/bash

# 默认使用当前目录的 tasks.txt
TASK_FILE="tasks.txt"
DELAY_SECONDS=5
CURRENT_SESSION_ID=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "用法: $0 [-f|--file <任务文件>] [延时秒数] [初始session_id]"
            echo ""
            echo "默认任务文件: tasks.txt (当前目录)"
            echo "任务文件格式: 以空行分隔的多行文本，每组为一个任务"
            echo ""
            echo "参数说明:"
            echo "  -f, --file     可选，指定任务文件，默认为 tasks.txt"
            echo "  延时秒数       可选，每个任务执行完后等待的秒数，默认5秒"
            echo "  初始session_id 可选，如果提供则从该session继续"
            echo ""
            echo "示例:"
            echo "  $0                           # 使用tasks.txt，延时5秒"
            echo "  $0 3                         # 使用tasks.txt，延时3秒"
            echo "  $0 0                         # 使用tasks.txt，不延时"
            echo "  $0 3 sess_xxx                # 使用tasks.txt，延时3秒，从sess_xxx继续"
            echo "  $0 -f tasks2.txt             # 使用tasks2.txt，延时5秒"
            echo "  $0 --file tasks2.txt 3       # 使用tasks2.txt，延时3秒"
            echo "  $0 -f mytasks.txt 0 sess_xxx # 使用mytasks.txt，不延时，从sess_xxx继续"
            exit 0
            ;;
        -f|--file)
            TASK_FILE="$2"
            shift 2
            ;;
        *)
            # 第一个数字参数是延时秒数
            if [[ "$1" =~ ^[0-9]+$ ]] && [ -z "$DELAY_SET" ]; then
                DELAY_SECONDS="$1"
                DELAY_SET=1
                shift
            # 第二个参数如果以sess_开头，则是session_id
            elif [[ "$1" =~ ^sess_ ]]; then
                CURRENT_SESSION_ID="$1"
                shift
            else
                echo "错误: 未知参数 '$1'"
                echo "使用 -h 或 --help 查看帮助信息"
                exit 1
            fi
            ;;
    esac
done

# 检查任务文件是否存在
if [ ! -f "$TASK_FILE" ]; then
    echo "错误: 任务文件 '$TASK_FILE' 不存在"
    echo "提示: 请创建任务文件或使用 -f 指定其他文件"
    echo "或使用 -h 查看帮助信息"
    exit 1
fi

# 创建输出文件保存session_id
OUTPUT_FILE="session_ids_$(date +%Y%m%d_%H%M%S).txt"
LOG_FILE="task_execution_$(date +%Y%m%d_%H%M%S).log"

echo "开始处理任务..."
echo "任务文件: $TASK_FILE"
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

# 读取任务文件并按空行分组处理
CURRENT_TASK=""
while IFS= read -r line || [ -n "$line" ]; do
    # 检查是否为空行
    if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
        # 遇到空行，如果当前有累积的任务内容，则执行
        if [ -n "$CURRENT_TASK" ]; then
            # 去除首尾空白
            task=$(echo "$CURRENT_TASK" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            if [ -n "$task" ]; then
                TASK_COUNT=$((TASK_COUNT + 1))

                echo "" | tee -a "$LOG_FILE"
                echo "====================================" | tee -a "$LOG_FILE"
                echo "任务 #$TASK_COUNT:" | tee -a "$LOG_FILE"
                echo "---" | tee -a "$LOG_FILE"
                echo "$task" | tee -a "$LOG_FILE"
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
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行: claude -p --resume $CURRENT_SESSION_ID" >> "$LOG_FILE"

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
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行: claude -p" >> "$LOG_FILE"

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
            fi

            # 清空当前任务缓存
            CURRENT_TASK=""
        fi
    else
        # 非空行，跳过注释行，累积任务内容
        if ! [[ "$line" =~ ^[[:space:]]*# ]]; then
            if [ -n "$CURRENT_TASK" ]; then
                CURRENT_TASK="$CURRENT_TASK"$'\n'"$line"
            else
                CURRENT_TASK="$line"
            fi
        fi
    fi
done < "$TASK_FILE"

# 处理文件末尾没有空行的情况
if [ -n "$CURRENT_TASK" ]; then
    task=$(echo "$CURRENT_TASK" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    if [ -n "$task" ]; then
        TASK_COUNT=$((TASK_COUNT + 1))

        echo "" | tee -a "$LOG_FILE"
        echo "====================================" | tee -a "$LOG_FILE"
        echo "任务 #$TASK_COUNT:" | tee -a "$LOG_FILE"
        echo "---" | tee -a "$LOG_FILE"
        echo "$task" | tee -a "$LOG_FILE"
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
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行: claude -p --resume $CURRENT_SESSION_ID" >> "$LOG_FILE"

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
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行: claude -p" >> "$LOG_FILE"

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
        fi
        echo "====================================" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
fi

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
