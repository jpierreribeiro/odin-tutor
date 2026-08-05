package main
import "core:fmt"
import "core:os"

main :: proc() {
	r, w, err := os.pipe()
	if err != nil { fmt.println("PIPE_ERRO", err); return }
	desc := os.Process_Desc{
		command = []string{"gdb", "--version"},
		stdout  = w,
		stderr  = w,
	}
	p, serr := os.process_start(desc)
	if serr != nil { fmt.println("START_ERRO", serr); return }
	os.close(w)
	buf: [4096]byte
	n, rerr := os.read(r, buf[:])
	st, werr := os.process_wait(p)
	fmt.println("BYTES_LIDOS:", n, "| read_err:", rerr, "| wait_err:", werr, "| exit:", st.exit_code)
	if n > 0 { fmt.println("SAIDA:", string(buf[:min(n,45)])) }
}
