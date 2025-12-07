# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository provides a Bash script (`run_tasks.sh`) for executing multiple Claude Code tasks sequentially, with session persistence across tasks. It enables automation of multi-step workflows where each task's context carries over to the next.

## Core Architecture

### Task Execution Flow

The `run_tasks.sh` script implements a sequential task processor with the following architecture:

1. **Task File Format**: `tasks.txt` contains prompts separated by blank lines. Each group of non-empty lines forms a single task.
2. **Session Chaining**: After the first task creates a session, subsequent tasks use `--resume` with the previous session ID, maintaining context across all tasks.
3. **Output Handling**: Uses `--output-format json` to extract session IDs and results programmatically.
4. **Error Resilience**: Failed tasks don't break the chain; the script continues with the next task using the last successful session ID.

### Key Files

- `run_tasks.sh`: Main task execution engine (317 lines)
  - Parses tasks from `tasks.txt`
  - Executes `claude -p` commands with session management
  - Logs all output to timestamped files
  - Line 85-145: Core task execution logic with session handling

- `tasks.txt`: Task definition file
  - Format: multi-line prompts separated by blank lines
  - Lines starting with `#` are treated as comments

- `auto_push.sh`: Git automation utility for quick commits/pushes

### Script Installation

The `usermanual` file shows the script can be installed globally:
```bash
sudo cp ./run_tasks.sh /usr/local/bin/myclaude
sudo chmod 777 /usr/local/bin/myclaude
```

## Commands

### Running Tasks

```bash
# Basic usage (default: 5 second delay between tasks)
./run_tasks.sh

# Custom delay between tasks
./run_tasks.sh 3            # 3 second delay
./run_tasks.sh 0            # No delay

# Resume from specific session
./run_tasks.sh 5 sess_xxx   # 5 second delay, continue from sess_xxx

# Get help
./run_tasks.sh -h
```

### Git Workflow

```bash
# Auto-commit and push with timestamp
./auto_push.sh

# Auto-commit with custom message
./auto_push.sh "Your commit message"
```

## Important Implementation Details

### Session Management
- First task creates a new session without `--resume`
- All subsequent tasks use `--resume $CURRENT_SESSION_ID` (line 85, 222)
- Session IDs are extracted from JSON output using `jq` (line 92, 229)
- If a task fails to return a session ID, the script preserves the previous session ID for continuity (line 164)

### Output Files
- `session_ids_YYYYMMDD_HHMMSS.txt`: Maps each task to its session ID
- `task_execution_YYYYMMDD_HHMMSS.log`: Complete execution log with timestamps

### Dependencies
- Requires `claude` CLI installed and configured
- Requires `jq` for JSON parsing
- Uses `--dangerously-skip-permissions` flag for non-interactive execution

### Task File Parsing
- Blank lines separate tasks (line 57)
- Comment lines starting with `#` are ignored (line 186)
- Whitespace is trimmed from task content (line 61, 198)
- Handles files both with and without trailing blank lines (line 196-305)
