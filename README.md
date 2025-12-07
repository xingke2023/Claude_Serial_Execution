# Claude Serial Execution

A Bash script for executing multiple Claude Code tasks sequentially with automatic session persistence. Perfect for automating complex multi-step workflows where context needs to be maintained across tasks.

## Features

- **Sequential Task Execution**: Run multiple Claude Code prompts one after another
- **Session Persistence**: Automatically chains sessions so each task has context from previous tasks
- **Flexible Task Format**: Define tasks in a simple text file with blank-line separators
- **Customizable Delays**: Control wait time between tasks
- **Detailed Logging**: Automatic timestamped logs of all execution details
- **Error Resilience**: Continues execution even if individual tasks fail
- **Resume Support**: Can resume from a specific session ID

## Prerequisites

- [Claude Code CLI](https://claude.ai/code) installed and configured
- `jq` for JSON parsing: `brew install jq` (macOS) or `apt-get install jq` (Linux)
- Bash shell

## Installation

### Quick Start

```bash
git clone https://github.com/yourusername/Claude_Serial_Execution.git
cd Claude_Serial_Execution
chmod +x run_tasks.sh auto_push.sh
```

### Global Installation (Optional)

Install as a global command `myclaude`:

```bash
sudo cp ./run_tasks.sh /usr/local/bin/myclaude
sudo chmod +x /usr/local/bin/myclaude
```

Then use from anywhere:
```bash
myclaude 5
```

## Usage

### 1. Create Your Task File

Create or edit `tasks.txt` with your prompts. Separate each task with a blank line:

```
Analyze the performance of my application and identify bottlenecks

Optimize the database queries based on the analysis above

Write unit tests for the optimized code
```

**Task File Format:**
- Each task can span multiple lines
- Separate tasks with one or more blank lines
- Lines starting with `#` are treated as comments
- Whitespace is automatically trimmed

### 2. Run Tasks

```bash
# Basic usage with 5-second delay (default)
./run_tasks.sh

# Custom delay between tasks
./run_tasks.sh 3            # 3-second delay
./run_tasks.sh 0            # No delay

# Resume from specific session
./run_tasks.sh 5 sess_xxxxx

# View help
./run_tasks.sh -h
```

### 3. Check Output

The script generates two output files:

- **`session_ids_YYYYMMDD_HHMMSS.txt`**: Maps each task to its session ID
- **`task_execution_YYYYMMDD_HHMMSS.log`**: Complete execution log with timestamps

## How It Works

1. **First Task**: Creates a new Claude Code session
2. **Subsequent Tasks**: Automatically resume the previous session using `--resume`
3. **Context Preservation**: Each task has full context from all previous tasks in the chain
4. **Session Tracking**: Extracts and stores session IDs for continuity

### Example Workflow

```
Task 1: "Create a user authentication module"
  → Creates session sess_abc123

Task 2: "Add password reset functionality"
  → Resumes sess_abc123, knows about the auth module

Task 3: "Write tests for the authentication system"
  → Resumes sess_abc123, knows about both auth module and password reset
```

## Examples

### Example 1: Code Review and Fixes

```
# tasks.txt
Review the code in src/auth.js and identify issues

Fix the security vulnerabilities you found

Add comprehensive error handling
```

### Example 2: Feature Development

```
# tasks.txt
Implement a caching layer using Redis for the API endpoints

Update the API documentation to reflect the caching behavior

Write integration tests for the caching functionality
```

### Example 3: Debugging Workflow

```
# tasks.txt
Analyze the error logs and identify the root cause of the timeout issues

Propose and implement a fix for the timeout problem

Verify the fix works and add monitoring
```

## Additional Tools

### Auto Push Script

Quickly commit and push changes to GitHub:

```bash
# Push with timestamp commit message
./auto_push.sh

# Push with custom message
./auto_push.sh "Add new feature"
```

## Command Reference

### run_tasks.sh

```bash
./run_tasks.sh [delay_seconds] [initial_session_id]
```

**Parameters:**
- `delay_seconds` (optional): Wait time between tasks, default 5 seconds
- `initial_session_id` (optional): Resume from this session

**Flags:**
- `-h, --help`: Display help information

### Output Format

The script displays real-time progress:

```
====================================
任务 #1:
---
Your task prompt here
====================================

>>> 首次执行，创建新会话
>>> 正在执行 claude 命令，请稍候...

--- Claude 执行结果 ---
[Claude's response]
--- 结果结束 ---

====================================
✓ 任务 #1 完成
✓ 本次任务的 Session ID: sess_xxxxx
====================================

⏱️  等待 5 秒后执行下一个任务...
```

## Tips

- **Keep Tasks Focused**: Each task should be a clear, actionable step
- **Use Context**: Later tasks can reference work done in earlier tasks
- **Check Logs**: Review the execution logs for detailed output
- **Adjust Delays**: Use longer delays for heavy tasks, shorter for simple ones
- **Resume on Failure**: If execution stops, resume from the last successful session

## Troubleshooting

**"claude: command not found"**
- Install Claude Code CLI: `npm install -g @anthropic-ai/claude-code`

**"jq: command not found"**
- Install jq: `brew install jq` (macOS) or `apt-get install jq` (Linux)

**Tasks fail with permissions error**
- The script uses `--dangerously-skip-permissions` for automation
- Ensure your tasks don't require interactive approval

**Session not persisting**
- Check that JSON output is valid in the log file
- Verify `jq` is correctly parsing the session_id field

## License

MIT

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.
