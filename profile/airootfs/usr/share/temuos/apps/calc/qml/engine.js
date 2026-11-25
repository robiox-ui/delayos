.pragma library
// Calculator engine helpers (standard / scientific / programmer / converters / dates).

// ---------- number formatting ----------
function fmt(x) {
    if (typeof x !== "number") return String(x)
    if (!isFinite(x)) return isNaN(x) ? "결과가 정의되지 않음" : "0으로 나눌 수 없음"
    if (x === 0) return "0"
    const ax = Math.abs(x)
    if (ax >= 1e16 || ax < 1e-15) {
        let s = x.toExponential(15).replace(/\.?0+e/, "e")
        return s.replace("e+", "e+").replace("e-", "e-")
    }
    let s = parseFloat(x.toPrecision(16)).toString()
    if (s.indexOf("e") >= 0) return s
    return group(s)
}
function group(s) {             // "1234567.5" -> "1,234,567.5" (keeps a trailing ".")
    let neg = s[0] === "-"
    if (neg) s = s.substring(1)
    const dot = s.indexOf(".")
    let ip = dot >= 0 ? s.substring(0, dot) : s
    const fp = dot >= 0 ? s.substring(dot) : ""
    ip = ip.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return (neg ? "-" : "") + ip + fp
}

// ---------- precedence evaluation (scientific) ----------
const PREC = { "+": 1, "−": 1, "×": 2, "÷": 2, "mod": 2, "^": 3, "yroot": 3, "log_y": 3 }
function apply(op, a, b) {
    switch (op) {
    case "+": return a + b
    case "−": return a - b
    case "×": return a * b
    case "÷": return b === 0 ? (a === 0 ? NaN : Infinity) : a / b
    case "mod": return a - b * Math.floor(a / b)
    case "^": return Math.pow(a, b)
    case "yroot": return Math.pow(a, 1 / b)
    case "log_y": return Math.log(a) / Math.log(b)
    }
    return NaN
}
// tokens: numbers, operators (strings above), "(" , ")"
function evaluate(tokens) {
    const out = [], ops = []
    function reduce() {
        const op = ops.pop()
        const b = out.pop(), a = out.pop()
        out.push(apply(op, a, b))
    }
    for (const t of tokens) {
        if (typeof t === "number") out.push(t)
        else if (t === "(") ops.push(t)
        else if (t === ")") { while (ops.length && ops[ops.length - 1] !== "(") reduce(); ops.pop() }
        else {
            while (ops.length && ops[ops.length - 1] !== "(" &&
                   (PREC[ops[ops.length - 1]] > PREC[t] || (PREC[ops[ops.length - 1]] === PREC[t] && t !== "^"))) reduce()
            ops.push(t)
        }
    }
    while (ops.length) { if (ops[ops.length - 1] === "(") ops.pop(); else reduce() }
    return out.length ? out[out.length - 1] : 0
}

function factorial(n) {
    if (n < 0 || n !== Math.floor(n)) return gamma(n + 1)
    if (n > 170) return Infinity
    let r = 1
    for (let i = 2; i <= n; ++i) r *= i
    return r
}
function gamma(z) {                       // Lanczos approximation
    if (z < 0.5) return Math.PI / (Math.sin(Math.PI * z) * gamma(1 - z))
    z -= 1
    const g = 7, c = [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
                      -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7]
    let x = c[0]
    for (let i = 1; i < g + 2; i++) x += c[i] / (z + i)
    const t = z + g + 0.5
    return Math.sqrt(2 * Math.PI) * Math.pow(t, z + 0.5) * Math.exp(-t) * x
}

// programmer mode arithmetic lives in main.py (Python ints; V4 has no BigInt)

// ---------- unit converters ----------
// factor = value of 1 unit in the base unit
const UNITS = {
    "부피": [["밀리리터", 1e-3], ["세제곱센티미터", 1e-3], ["리터", 1], ["세제곱미터", 1000], ["티스푼(미국)", 0.00492892], ["테이블스푼(미국)", 0.0147868],
             ["액량 온스(미국)", 0.0295735], ["컵(미국)", 0.24], ["파인트(미국)", 0.473176], ["쿼트(미국)", 0.946353], ["갤런(미국)", 3.78541], ["갤런(영국)", 4.54609]],
    "길이": [["나노미터", 1e-9], ["마이크로미터", 1e-6], ["밀리미터", 1e-3], ["센티미터", 1e-2], ["미터", 1], ["킬로미터", 1000],
             ["인치", 0.0254], ["피트", 0.3048], ["야드", 0.9144], ["마일", 1609.344], ["해리", 1852]],
    "무게 및 질량": [["밀리그램", 1e-6], ["그램", 1e-3], ["킬로그램", 1], ["톤(미터법)", 1000], ["온스", 0.028349523125], ["파운드", 0.45359237], ["스톤", 6.35029318], ["근", 0.6], ["돈", 0.00375]],
    "온도": [["섭씨", "C"], ["화씨", "F"], ["켈빈", "K"]],
    "에너지": [["줄", 1], ["킬로줄", 1000], ["칼로리", 4.184], ["킬로칼로리", 4184], ["와트시", 3600], ["킬로와트시", 3.6e6], ["전자볼트", 1.602176634e-19], ["BTU", 1055.06]],
    "면적": [["제곱밀리미터", 1e-6], ["제곱센티미터", 1e-4], ["제곱미터", 1], ["헥타르", 1e4], ["제곱킬로미터", 1e6], ["제곱인치", 0.00064516],
             ["제곱피트", 0.09290304], ["에이커", 4046.8564224], ["평", 3.305785]],
    "속도": [["미터/초", 1], ["킬로미터/시", 1 / 3.6], ["마일/시", 0.44704], ["노트", 0.514444], ["마하", 340.3]],
    "시간": [["밀리초", 1e-3], ["초", 1], ["분", 60], ["시간", 3600], ["일", 86400], ["주", 604800], ["년", 31557600]],
    "전력": [["와트", 1], ["킬로와트", 1000], ["마력", 745.7], ["BTU/분", 17.584]],
    "데이터": [["비트", 1 / 8], ["바이트", 1], ["킬로바이트", 1e3], ["메가바이트", 1e6], ["기가바이트", 1e9], ["테라바이트", 1e12],
               ["키비바이트", 1024], ["메비바이트", 1048576], ["기비바이트", 1073741824]],
    "압력": [["파스칼", 1], ["킬로파스칼", 1000], ["바", 1e5], ["기압", 101325], ["mmHg", 133.322], ["PSI", 6894.757]],
    "각도": [["도", Math.PI / 180], ["라디안", 1], ["그레이드", Math.PI / 200]]
}
function convert(cat, v, from, to) {
    const list = UNITS[cat]
    const f = list[from][1], t = list[to][1]
    if (typeof f === "string") {           // temperature
        let c = f === "C" ? v : f === "F" ? (v - 32) * 5 / 9 : v - 273.15
        return t === "C" ? c : t === "F" ? c * 9 / 5 + 32 : c + 273.15
    }
    return v * f / t
}

// ---------- dates ----------
function daysBetween(a, b) {
    const ua = Date.UTC(a.getFullYear(), a.getMonth(), a.getDate())
    const ub = Date.UTC(b.getFullYear(), b.getMonth(), b.getDate())
    return Math.round((ub - ua) / 86400000)
}
// Korean form of the difference, e.g. "3주, 3일" / "1년, 2개월, 1주, 3일"
function diffText(a, b) {
    if (b < a) { const t = a; a = b; b = t }
    const total = daysBetween(a, b)
    if (total === 0) return "같은 날짜"
    let y = b.getFullYear() - a.getFullYear()
    let m = b.getMonth() - a.getMonth()
    let d = b.getDate() - a.getDate()
    if (d < 0) { m -= 1; d += new Date(b.getFullYear(), b.getMonth(), 0).getDate() }
    if (m < 0) { y -= 1; m += 12 }
    const w = Math.floor(d / 7); d = d % 7
    const parts = []
    if (y) parts.push(y + "년")
    if (m) parts.push(m + "개월")
    if (w) parts.push(w + "주")
    if (d) parts.push(d + "일")
    return parts.join(", ")
}
function dateText(dt) {
    return dt.getFullYear() + "년 " + (dt.getMonth() + 1) + "월 " + dt.getDate() + "일"
}
const WEEKDAYS = ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"]
function longDateText(dt) { return dateText(dt) + " " + WEEKDAYS[dt.getDay()] }
