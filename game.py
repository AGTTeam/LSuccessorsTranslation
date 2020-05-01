from hacktools import common

binrange = (445000, 884000)


def detectEncodedString(f, encoding):
    return common.detectEncodedString(f, "cp932", [0x25, 0x5c])
