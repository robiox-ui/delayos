.pragma library

// Classifies KRunner (Milou) matches for the Start / Command bar result rows (§4.3, §5).

function kindOf(matchId, category) {
    var id = String(matchId || "").toLowerCase()
    var cat = String(category || "").toLowerCase()
    if (id.indexOf("calculator") === 0 || id.indexOf("qalculate") === 0 || cat === "calculator" || cat === "계산기")
        return "calc"
    if (id.indexOf("unitconverter") === 0 || cat.indexOf("unit") >= 0 || cat.indexOf("단위") >= 0)
        return "unit"
    if (id.indexOf("webshortcuts") === 0 || id.indexOf("websearch") === 0)
        return "web"
    if (id.indexOf("krunner_services") === 0 || id.indexOf("services") === 0)
        return "app"
    if (id.indexOf("krunner_systemsettings") === 0)
        return "settings"
    return "other"
}

// left part of "5 ft in cm" / "40 usd to eur" -> "5 ft" / "40 usd"
function conversionSource(query) {
    var q = String(query).trim()
    var m = q.split(/\s+(?:in|to|as|into|->|=|>)\s+/i)
    return m.length > 1 ? m[0] : q
}

function isAnswer(kind) {
    return kind === "calc" || kind === "unit"
}

function glyphFor(kind) {
    if (kind === "calc") return "calculator"
    if (kind === "unit") return "arrow-left-right"
    if (kind === "web") return "globe"
    return ""
}

// subtitle shown for an answer row: "2450*0.18 = · Enter 키를 눌러 복사"
function answerSubtitle(kind, query, subtext) {
    var left = kind === "unit" ? conversionSource(query) : String(query).trim().replace(/^=/, "")
    var parts = [left + " ="]
    if (kind === "unit" && subtext && /\d{4}-\d{2}-\d{2}/.test(subtext))
        parts.push(String(subtext).match(/\d{4}-\d{2}-\d{2}/)[0] + " 기준 환율")
    parts.push("Enter 키를 눌러 복사")
    return parts.join("  ·  ")
}

// value to put on the clipboard for an answer ("152.4 cm" -> "152.4 cm", "441" -> "441")
function answerValue(display) {
    return String(display).replace(/^=\s*/, "").trim()
}

function webSearchUrl(query) {
    return "https://duckduckgo.com/?q=" + encodeURIComponent(query)
}
