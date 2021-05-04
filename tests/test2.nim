import
    catnip/[x64assembler, reprotect]

var
    exememory {.align(4096).}: array[1*1024*1024, byte]

proc main =
    doAssert (cast[int64](addr exememory[0]) and 0xFFF) == 0, "memory is not page aligned"
    doAssert reprotectMemory(addr exememory[0], sizeof(exememory), {memperm_R, memperm_W, memperm_X})

    var s = initAssemblerX64(cast[ptr UncheckedArray[byte]](addr exememory[0]))

    let entryPoint = s.getFuncStart[:proc(): int32 {.cdecl.}]()
    s.mov(reg(regEax), 42)
    s.ret()

    doAssert entryPoint() == 42

main()