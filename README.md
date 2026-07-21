# HUST-EIC-COP-basedon-MIPS
华中科技大学电信学院微机原理期末综合项目，基于FPGA的VGA贪吃蛇
基于Xilinx Nexys 4 ddr开发板设计，注意硬件引脚编号，vivado版本为2018.2
直接解压缩到vivado project存放的文件夹，打开vga_snake.xpr文件即可
BSP为vga_snake_app_bsp，比特流文件位于vga_snake.runs\impl_1\board_top.bit
开发板需接VGA主动转HDMI到显示屏，波特率为115200
由开发板的btnc控制开始与暂停，由btnu，btnl，btnr，btnd控制方向，每次操作会在skd终端打印状态
项目贡献者为yhl，lh，和他们的deepseek，gpt和claude老师
