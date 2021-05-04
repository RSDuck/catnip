type
    MemPerm* = enum
        memperm_R
        memperm_W
        memperm_X

when defined(windows):
    import winlean
    
    proc virtualProtect(lpAddress: pointer, dwSize: WinSizeT, flNewProtect: DWORD,
            lpflOldProtect: PDWORD): WINBOOL
        {.stdcall, dynlib: "kernel32", importc: "VirtualProtect", sideeffect.}

    proc reprotectMemory*(adr: pointer, size: int, perms: set[MemPerm]): bool =
        let perms =
            if perms == {memperm_R}: PAGE_READONLY
            elif perms == {memperm_R, memperm_W}: PAGE_READWRITE
            elif perms == {memperm_R, memperm_W, memperm_X}: PAGE_EXECUTE_READWRITE
            else: raiseAssert("unsupported protection")
        var oldProtect: DWORD
        int32(virtualProtect(adr, WinSizeT size, perms, addr oldProtect)) != 0
else:
    {.fatal: "unsupported platform :(".}