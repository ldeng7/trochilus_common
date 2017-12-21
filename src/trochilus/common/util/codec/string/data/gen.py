import sys
ENC = sys.argv[1]

f = open("./ucs16_to_" + ENC + ".lua", 'w')
unis = [eval(r'u"\u' + ("%04x" % (i)) + '"') for i in range(65536)]
encs = []
for i in range(65536):
    try:
        c = unis[i].encode(ENC)
    except Exception, e:
        c = None
    encs.append(c)
f.write("return {\n")
i = 0
s = "    "
for c in encs:
    if None == c:
        s += "0,          "
    elif len(c) == 1:
        s += (r'"\x%02x",     ' % (ord(c)))
    elif len(c) == 2:
        s += (r'"\x%02x\x%02x", ' % (ord(c[0]), ord(c[1])))
    else:
        f.write("error at " + c + "!\n")
    i += 1
    if i == 8:
        f.write(s.rstrip() + "\n")
        i = 0
        s = "    "
f.write("}\n")
f.flush()
f.close()

f = open("./" + ENC + "_to_ucs16.lua", 'w')
encs = [eval(r'"\x' + ("%02x" % (i)) + r'\x' + ("%02x" % (j)) + '"') for i in range(128, 256) for j in range(256)]
unis = []
for i in range(32768):
    try:
        u = encs[i].decode(ENC)
        if len(u) != 1:
            u = None
    except Exception, e:
        u = None
    unis.append(u)
f.write("return {\n")
i = 0
s = "    "
for u in unis:
    if None == u:
        s += "0,      "
    else:
        s += ("0x%04x, " % (ord(u)))
    i += 1
    if i == 8:
        f.write(s.rstrip() + "\n")
        i = 0
        s = "    "
f.write("}\n")
f.flush()
f.close()
