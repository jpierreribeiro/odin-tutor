package main
import "core:fmt"
import "core:os"

main :: proc() {
	r, w, err := os.pipe()
	if err != nil { fmt.println("PIPE_ERROR", err); return }
	desc := os.Process_Desc{
		command = []string{"gdb", "--version"},
		stdout  = w,
		stderr  = w,
	}
	p, serr := os.process_start(desc)
	if serr != nil { fmt.println("START_ERROR", serr); return }
	os.close(w)
	buf: [4096]byte
	n, rerr := os.read(r, buf[:])
	st, werr := os.process_wait(p)
	fmt.println("BYTES_READ:", n, "| read_err:", rerr, "| wait_err:", werr, "| exit:", st.exit_code)
	if n > 0 { fmt.println("OUTPUT:", string(buf[:min(n,45)])) }
}
