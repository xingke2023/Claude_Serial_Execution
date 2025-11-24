提供了一种Claude code 串联执行的方式

确保执行Claude code 每一条任务
执行完上一条才执行下一条，可以加入延时功能

使用示例：

  默认使用（5秒延时，无初始session）：
  ./run_tasks.sh tasks_example.txt

  自定义延时10秒：
  ./run_tasks.sh tasks_example.txt 10

  禁用延时（0秒）：
  ./run_tasks.sh tasks_example.txt 0

  延时3秒 + 指定初始session_id：
  ./run_tasks.sh tasks_example.txt 3 abc123-session-id-here

  使用默认延时5秒 + 指定初始session_id：
  ./run_tasks.sh tasks_example.txt 5 abc123-session-id-here
