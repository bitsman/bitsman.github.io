#!/bin/bash 
socat pty,link=/tmp/ttyNET0,rawer tcp:192.168.11.195:8010
