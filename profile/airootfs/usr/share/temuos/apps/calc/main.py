"""계산기 (TEMUOS Calculator) — PySide6 backend (programmer-mode integer maths, settings)."""
import json
import os
import sys

sys.path.insert(0, "/usr/share/temuos/apps/common")
from temuapp import run  # noqa: E402

from PySide6.QtCore import QObject, Slot  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "temuos-calc.json")

PREC = {"|": 1, "nor": 1, "^x": 2, "&": 3, "nand": 3, "<<": 4, ">>": 4, "rol": 4, "ror": 4,
        "+": 5, "−": 5, "×": 6, "÷": 6, "%": 6}


def wrap(v, bits):
    m = 1 << bits
    v %= m
    return v - m if v >= m >> 1 else v


def unsigned(v, bits):
    return v % (1 << bits)


def _apply(op, a, b, bits):
    if op == "+": return a + b
    if op == "−": return a - b
    if op == "×": return a * b
    if op in ("÷", "%"):
        if b == 0:
            raise ZeroDivisionError
        q = abs(a) // abs(b)
        q = q if (a >= 0) == (b >= 0) else -q          # truncate like C
        return q if op == "÷" else a - q * b
    if op == "&": return a & b
    if op == "|": return a | b
    if op == "^x": return a ^ b
    if op == "nand": return ~(a & b)
    if op == "nor": return ~(a | b)
    if op == "<<": return a << min(b, bits)
    if op == ">>": return a >> min(b, bits)
    if op in ("rol", "ror"):
        u, n = unsigned(a, bits), b % bits
        if op == "ror":
            n = (bits - n) % bits
        return ((u << n) | (u >> (bits - n))) & ((1 << bits) - 1)
    return 0


class Backend(QObject):
    @Slot(str, int, result=str)
    def progEval(self, tokens_json, bits):
        """tokens: decimal strings, operators, '(' and ')'. Returns a decimal string or '' on error."""
        out, ops = [], []

        def reduce():
            op = ops.pop()
            b = out.pop() if out else 0
            a = out.pop() if out else 0
            out.append(wrap(_apply(op, a, b, bits), bits))
        try:
            for t in json.loads(tokens_json):
                if t == "(":
                    ops.append(t)
                elif t == ")":
                    while ops and ops[-1] != "(":
                        reduce()
                    if ops:
                        ops.pop()
                elif t in PREC:
                    while ops and ops[-1] != "(" and PREC[ops[-1]] >= PREC[t]:
                        reduce()
                    ops.append(t)
                else:
                    out.append(wrap(int(t), bits))
            while ops:
                if ops[-1] == "(":
                    ops.pop()
                else:
                    reduce()
        except (ZeroDivisionError, ValueError):
            return ""
        return str(out[-1] if out else 0)

    @Slot(str, int, result="QVariant")
    def progFormat(self, dec, bits):
        try:
            v = wrap(int(dec or "0"), bits)
        except ValueError:
            v = 0
        u = unsigned(v, bits)

        def grp(s, n, sep=" "):
            s = s[::-1]
            return sep.join(s[i:i + n] for i in range(0, len(s), n))[::-1]
        return {"HEX": grp("%X" % u, 4), "DEC": "{:,}".format(v), "OCT": grp("%o" % u, 3),
                "BIN": grp(bin(u)[2:], 4), "dec": str(v)}

    @Slot(str, int, int, result=str)
    def progParse(self, text, base, bits):
        s = text.replace(" ", "").replace(",", "")
        if not s or s == "-":
            return "0"
        try:
            return str(wrap(int(s, base), bits))
        except ValueError:
            return "0"

    @Slot(str, int, result=str)
    def progNot(self, dec, bits):
        return str(wrap(~int(dec or "0"), bits))

    @Slot(str, int, result=str)
    def progNeg(self, dec, bits):
        return str(wrap(-int(dec or "0"), bits))

    @Slot(result=str)
    def loadState(self):
        try:
            with open(CONF, encoding="utf-8") as f:
                return f.read()
        except OSError:
            return ""

    @Slot(str)
    def saveState(self, s):
        try:
            with open(CONF, "w", encoding="utf-8") as f:
                f.write(s)
        except OSError:
            pass


def main():
    return run("org.temuos.Calculator", os.path.join(HERE, "qml", "Main.qml"),
               context={"backend": Backend()}, name="계산기")


if __name__ == "__main__":
    sys.exit(main())
