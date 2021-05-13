import
    streams,
    catnip/x64assembler

template testNormalOp(name): untyped =
    # register
    s.name(reg(regEax), 32)
    s.name(reg(regEcx), 32)
    s.name(reg(regEcx), -1)
    s.name(reg(regAl), -1)
    s.name(reg(regBpl), -1)
    s.name(reg(regR8), regRax)
    s.name(regRax, reg(regR8))
    s.name(regR15, reg(regR15))
    s.name(reg(regR15), 0xFFFFF)
    s.name(reg(regAx), -54)
    s.name(reg(regCx), 1)
    # memory
    s.name(mem32(regRax), regEax)
    s.name(regR13, mem64(regRsp))
    s.name(regR8d, mem32(regRbp))
    s.name(regR8d, mem32(regRax, -2, rmScale8))
    s.name(mem32(regRax, regR12, -1, rmScale8), regEdx)
    s.name(mem16(regR13, 0x234), regAx)
    s.name(mem8(regRax, 0x12), regSpl)
    s.name(mem8(regRbp, 0x12, rmScale4), regSpl)
    s.name(mem16(regRax), 0x21)
    s.name(mem16(addr s.data[0]), 0x21)

proc main =
    var
        data: array[0x10000, byte]
        s = initAssemblerX64(cast[ptr UncheckedArray[byte]](addr data[0]))

    # add
    testNormalOp(add)
    testNormalOp(sub)
    testNormalOp(aand)
    testNormalOp(xxor)
    testNormalOp(oor)
    testNormalOp(mov)

    s.ret()

    s.mov(regRax, 0xFAFAFA)
    s.mov(regR13, 0xFAFAFA)
    s.mov(reg(regR13d), 0xFAFAFA)
    s.mov(reg(regRax), 0xFAFAFA)

    s.movzx(regEax, reg(regAl))
    s.movzx(regEax, reg(regAx))
    s.movsx(regEax, reg(regR14b))
    s.movsx(regEax, reg(regAx))
    s.movsx(regAx, reg(regAl))
    s.movsx(regAx, mem8(regRsp))
    s.movsx(regR8, mem16(regRsp, 0x9876))

    s.rcl(reg(regAl), 1)
    s.rcl(reg(regAl), 2)
    s.sar(reg(regAx), 2)
    s.sshl(reg(regEax), 4)
    s.rcr(reg(regR8), 21)
    s.rcr(reg(regR8d))
    s.ror(reg(regR8))
    s.rol(reg(regR8b))

    s.test(reg(regAl), 1)
    s.test(mem32(regRax), 1)
    s.test(mem32(regRax), 1)
    s.test(mem32(regRax), regR12d)

    let skip0 = s.label()

    s.push(reg(regRax))
    s.push(reg(regR14))
    s.push(mem64(regR14))

    s.jmp(skip0)
    let skip1 = s.jmp(true)

    s.pop(reg(regRax))
    s.pop(reg(regR14))
    s.pop(mem64(regR14))
    s.pop(mem64(regR14))

    s.label(skip1)
    let
        skip2 = s.jmp(false)
        skip3 = s.jcc(condZero, false)
        skip4 = s.jcc(condLequal, true)
    s.setcc(reg(regAl), condBelow)
    s.setcc(reg(regR12b), condZero)
    s.setcc(mem8(regRbp), condZero)

    s.label(skip2)
    s.label(skip3)
    s.label(skip4)

    s.bswap(regEax)
    s.bswap(regR13d)
    s.bswap(regR12)

    s.neg(reg(regEax))
    s.neg(reg(regR8b))
    s.nnot(mem8(regRax))
    s.nnot(mem64(regRbp))

    s.call(addr data[0])

    s.bt(reg(regEax), 12)
    s.bts(reg(regRax), 16)
    s.btr(mem16(regRax), 14)
    s.btc(mem32(regRax), 31)

    s.bt(reg(regEax), regEax)
    s.bts(reg(regRax), regR8)
    s.btr(mem16(regRax), regCx)
    s.btc(mem32(regRax), regR12d)

    s.imul(reg(regR8b))
    s.imul(mem16(regRbp, regRax, 0, rmScale8))
    s.imul(reg(regR15d))
    s.imul(reg(regRax))

    s.imul(regAx, mem16(regRbp))
    s.imul(regR14d, reg(regR15d))
    s.imul(regRax, reg(regRax))

    s.imul(regAx, mem16(regRbp), 2)
    s.imul(regR10d, reg(regR15d), 0xFFF)
    s.imul(regRax, reg(regRax), 0x1234)

    s.mul(reg(regAl))
    s.mul(reg(regAx))
    s.mul(reg(regEax))
    s.mul(reg(regRax))

    s.ddiv(reg(regR12b))
    s.ddiv(mem16(regRsp))
    s.ddiv(reg(regRax))
    s.ddiv(mem64(regR14))

    s.idiv(reg(regR12b))
    s.idiv(mem16(regRsp))
    s.idiv(reg(regRax))
    s.idiv(mem64(addr data[0]))

    s.lea(regAx, mem32(regRax, regRax, -1, rmScale4))
    s.lea(regAx, mem64(regRax, regRax, -1, rmScale4))
    s.lea(regEax, mem32(regRax, regRax, -1, rmScale4))
    s.lea(regEax, mem64(regRax, regRax, -1, rmScale4))
    s.lea(regRax, mem32(regRax, regRax, -1, rmScale4))
    s.lea(regRax, mem64(regRax, regRax, -1, rmScale4))

    s.nop(1)
    s.nop(2)
    s.nop(3)
    s.nop(4)
    s.nop(5)
    s.nop(6)
    s.nop(7)
    s.nop(8)
    s.nop(9)
    s.nop(10)
    s.nop(23)
    s.nop(77)

    s.jmp(reg(regRax))
    s.jmp(reg(regR14))
    s.call(reg(regR14))

    s.push(reg(regRdi))
    s.push(reg(regRsi))
    s.push(reg(regRbx))
    s.push(reg(regR12))
    s.push(reg(regR13))
    s.push(reg(regR14))
    s.push(reg(regR15))
    s.push(reg(regRbp))
    s.sub(reg(regRsp), 8 + 1234)

    s.mov(reg(regRbp), param1)

    s.mov(mem32(regRbp, int32 1234), cast[int32](0xFFFF))

    let stream = newFileStream("assembled.bin", fmWrite)
    stream.writeData(addr data[0], s.offset)
    stream.close()

main()