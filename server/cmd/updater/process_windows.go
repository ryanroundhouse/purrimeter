package main

import "syscall"

func processAlive(pid int) bool {
	h, e := syscall.OpenProcess(0x1000, false, uint32(pid))
	if e != nil {
		return false
	}
	defer syscall.CloseHandle(h)
	var code uint32
	if syscall.GetExitCodeProcess(h, &code) != nil {
		return false
	}
	return code == 259
}
