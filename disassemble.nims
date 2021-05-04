echo "disassembling ", paramStr(3)
exec "objdump -D -b binary --insn-width 8 -mi386:x86-64 -M intel " & paramStr(3)