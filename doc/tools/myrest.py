#coding:utf8
import os
import time
import subprocess
BufferTime =   10    #缓冲时间，单位 秒
IntervalTime = 40    #间隔时间，单位 分钟
while True:
    time.sleep(IntervalTime*60)
    os.system("notify-send -u normal -i appointment-new '该休息了' '注意保护眼睛~'")
    time.sleep(BufferTime)
    os.system("gnome-screensaver-command -l")
    time.sleep(1)
    os.system("gnome-screensaver-command -a")
    #检查是否处于屏幕保护状态
    while True:
        x = subprocess.check_output(['gnome-screensaver-command','-q'])
        if "The screensaver is inactive" in str(x):
            #不处于屏幕保护状态
            break
        else:
            continue
        time.sleep(1)
