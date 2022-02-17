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
    s.name(regR13, mem64(regRsp, regRax))
    s.name(regR8d, mem32(regRbp))
    s.name(regR8d, mem32(regRax, -2, rmScale8))
    s.name(mem32(regRax, regR12, -1, rmScale8), regEdx)
    s.name(mem16(regR13, 0x234), regAx)
    s.name(mem8(regRax, 0x12), regSpl)
    s.name(mem8(regRbp, 0x12, rmScale4), regSpl)
    s.name(mem16(regRax), 0x21)
    s.name(mem16(addr s.data[0]), 0x21)

template testSseNormalOp(name): untyped =
    s.`name ps`(regXmm0, reg(regXmm1))
    s.`name ss`(regXmm15, reg(regXmm0))
    s.`name pd`(regXmm2, reg(regXmm3))
    s.`name sd`(regXmm1, reg(regXmm10))
    s.`name sd`(regXmm1, memXmm(regR12))
    s.`name ss`(regXmm12, memXmm(regR12))
    s.`name ps`(regXmm12, memXmm(regR12))

template testSseWeirdOp(name): untyped =
    s.`name ps`(regXmm0, reg(regXmm10))
    s.`name pd`(regXmm0, reg(regXmm10))
    s.`name pd`(regXmm9, memXmm(regRax, regRax))

template testSseMovLike(name): untyped =
    s.name(regXmm0, reg(regXmm12))
    s.name(regXmm12, memXmm(regRax))
    s.name(reg(regXmm12), regXmm14)
    s.name(memXmm(regR12), regXmm14)

template testSseMovLikeOneWay(name): untyped =
    s.name(regXmm0, reg(regXmm12))
    s.name(regXmm12, memXmm(regRax))
    s.name(regXmm14, reg(regXmm12))

template testSseRegOnly(name): untyped =
    s.name(regXmm0, regXmm12)
    s.name(regXmm14, regXmm12)

template testSsePartMemOp(name): untyped =
    s.name(memMemOnly(regRax), regXmm12)
    s.name(regXmm14, memMemOnly(regR15, regR12))

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
    s.ddiv(reg(regEax))
    s.ddiv(reg(regR10d))
    s.ddiv(mem64(regR14))

    s.test(reg(regR10d), regR10d)
    let skipDiv0 = s.jcc(condZero, false)
    s.ddiv(reg(regR10d))
    s.label skipDiv0

    s.idiv(reg(regR12b))
    s.idiv(mem16(regRsp))
    s.idiv(reg(regRax))
    s.idiv(mem64(addr data[0]))

    s.lea32(regAx, memMemOnly(regRax, regRax, -1, rmScale4))
    s.lea64(regAx, memMemOnly(regRax, regRax, -1, rmScale4))
    s.lea32(regEax, memMemOnly(regRax, regRax, -1, rmScale4))
    s.lea64(regEax, memMemOnly(regRax, regRax, -1, rmScale4))
    s.lea32(regRax, memMemOnly(regRax, regRax, -1, rmScale4))
    s.lea64(regRax, memMemOnly(regRax, regRax, -1, rmScale4))

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

    s.cmov(regEax, reg(regR12d), condNotLess)
    s.cmov(regRax, mem64(regR15), condNotLess)

    s.movsxd(regRax, reg(regEax))
    s.movsxd(regRax, reg(regR8d))
    s.movsxd(regR14, reg(regR8d))

    testSseNormalOp(sqrt)
    testSseNormalOp(add)
    testSseNormalOp(mul)
    testSseNormalOp(sub)
    testSseNormalOp(min)
    testSseNormalOp(max)

    testSseWeirdOp(aand)
    testSseWeirdOp(andn)
    testSseWeirdOp(oor)
    testSseWeirdOp(xxor)

    testSseMovLike(movups)
    testSseMovLike(movss)
    testSseMovLike(movupd)
    testSseMovLike(movsd)
    testSseMovLikeOneWay(movddup)
    testSseMovLikeOneWay(movsldup)
    testSseMovLikeOneWay(movshdup)
    testSseMovLikeOneWay(unpcklps)
    testSseMovLikeOneWay(unpcklpd)
    testSseMovLikeOneWay(unpckhps)
    testSseMovLikeOneWay(unpckhpd)
    testSseMovLike(movaps)
    testSseMovLike(movapd)
    testSseMovLike(movdqa)
    testSseMovLike(movdqu)

    testSseRegOnly(movhlps)
    testSseRegOnly(movlhps)

    testSsePartMemOp(movlps)
    testSsePartMemOp(movlpd)
    testSsePartMemOp(movhps)
    testSsePartMemOp(movhpd)

    s.movd(regXmm0, reg(regEax))
    s.movd(regXmm6, mem32(regRsp))
    s.movd(reg(regEax), regXmm0)
    s.movd(mem32(regR10), regXmm6)
    s.movq(regXmm0, reg(regRax))
    s.movq(regXmm6, mem64(regRsp))
    s.movq(reg(regRax), regXmm0)
    s.movq(mem64(regR10), regXmm6)

    s.cvtsi2ss(regXmm0, mem32(regR12))
    s.cvtsi2ss(regXmm15, reg(regR12))

    s.cvtsi2sd(regXmm0, reg(regR12))
    s.cvtsi2sd(regXmm15, mem64(regR12))

    s.cvttss2si(regR12d, reg(regXmm8))
    s.cvttss2si(regR12, memXmm(regRax))

    s.cvttsd2si(regR12, memXmm(regRax, regRbp))
    s.cvttsd2si(regRax, reg(regXmm0))

    s.cvtss2si(regR12d, memXmm(regR8))
    s.cvtss2si(regR9, reg(regXmm1))

    s.cvtsd2si(regR12d, memXmm(regR8))
    s.cvtsd2si(regR9, reg(regXmm1))

    s.ucomiss(regXmm0, reg(regXmm1))
    s.ucomiss(regXmm0, memXmm(regRax))

    s.comiss(regXmm0, reg(regXmm1))
    s.comiss(regXmm12, memXmm(regRax))

    testSseMovLikeOneWay(cvtps2pd)
    testSseMovLikeOneWay(cvtpd2ps)
    testSseMovLikeOneWay(cvtss2sd)
    testSseMovLikeOneWay(cvtsd2ss)
    testSseMovLikeOneWay(cvtdq2ps)
    testSseMovLikeOneWay(cvtps2dq)
    testSseMovLikeOneWay(cvttps2dq)
    testSseMovLikeOneWay(cvtdq2pd)
    testSseMovLikeOneWay(cvtpd2dq)
    testSseMovLikeOneWay(cvttpd2dq)

    s.shufps(regXmm0, reg(regXmm1), 0)
    s.shufps(regXmm12, memXmm(regRax), cast[int8](0xFF))
    s.shufpd(regXmm0, reg(regXmm1), 0)
    s.shufpd(regXmm12, memXmm(regRax), cast[int8](0x3))

    block:
        s.test(reg(regR8d), regR8d)
        let skipDiv0 = s.jcc(condZero, false)
        s.cmp(reg(regR8d), -1)
        let divisorNotMinusOne = s.jcc(condNotZero, false)
        s.cmp(reg(regEax), low(int32))
        let skipDivLowest = s.jcc(condZero, false)
        s.label(divisorNotMinusOne)
        s.idiv(reg(regR8d))
        s.label skipDiv0
        s.label skipDivLowest

    s.cwd()
    s.cdq()
    s.cqo()

    s.cbw()
    s.cwde()
    s.cdqe()

    block:
        let funcStart = s.label()
        s.sub(reg(param1), 1)
        s.jcc(condNotZero, funcStart)
        s.ret()

    s.movbe(regR15w, memMemOnly(regRax))
    s.movbe(regAx, memMemOnly(regR15))
    s.movbe(regEax, memMemOnly(regRax))
    s.movbe(regEax, memMemOnly(regR15))
    s.movbe(regRax, memMemOnly(regRax))
    s.movbe(regRax, memMemOnly(regR15))
    s.movbe(regAx, memMemOnly(regRax, regRax))
    s.movbe(regR12w, memMemOnly(regR15, regRbp))
    s.movbe(regAx, memMemOnly(regR15, regRax))
    s.movbe(regEax, memMemOnly(regRax, regRax))
    s.movbe(regEax, memMemOnly(regR15, regRax))
    s.movbe(regRax, memMemOnly(regRax, regRax))
    s.movbe(regRax, memMemOnly(regR15, regRax))
    s.movbe(memMemOnly(regRax, regRax), regAx)
    s.movbe(memMemOnly(regRax, regR15), regAx)
    s.movbe(memMemOnly(regRax, regRax), regEax)
    s.movbe(memMemOnly(regRax, regR15), regEax)
    s.movbe(memMemOnly(regRax, regRax), regRax)
    s.movbe(memMemOnly(regRax, regR15), regRax)

    s.pushf()
    s.pushfq()
    s.popf()
    s.popfq()

    let stream = newFileStream("assembled.bin", fmWrite)
    stream.writeData(addr data[0], s.offset)
    stream.close()

main()