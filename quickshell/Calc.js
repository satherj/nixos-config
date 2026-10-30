.pragma library
// Spotlight-style calculator for the launcher. A small recursive-descent parser (no eval), so
// typing in the search box can never run code.
//   + - * / ^ (or **), × ÷, parentheses, unary minus, postfix ! (factorial) and % (percent),
//   "mod", implicit multiplication (2pi, 3(4+1)), constants pi/e/tau, and the functions below.
// evaluate() returns null unless the whole query parses AND contains an operator or function,
// so a bare "42" or "e" keeps searching apps instead of turning into a calculator row.

var fns = {
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, exp: Math.exp,
    ln: Math.log, log: Math.log10, log2: Math.log2, log10: Math.log10,
    sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
    sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh,
    floor: Math.floor, ceil: Math.ceil, round: Math.round, trunc: Math.trunc,
    min: Math.min, max: Math.max, pow: Math.pow, hypot: Math.hypot
};
var consts = { pi: Math.PI, "π": Math.PI, e: Math.E, tau: 2 * Math.PI };

function tokenize(s) {
    var out = [];
    var re = /\s*(?:(\d[\d_]*(?:\.\d*)?(?:e[+-]?\d+)?|\.\d+(?:e[+-]?\d+)?)|([a-zπ][a-z0-9]*)|(\*\*|[-+*\/^()!%,×÷−]))/giy;
    var m;
    re.lastIndex = 0;
    while (re.lastIndex < s.length) {
        if (/^\s*$/.test(s.slice(re.lastIndex)))
            break;
        m = re.exec(s);
        if (!m)
            return null;
        if (m[1] !== undefined)
            out.push({ t: "num", v: parseFloat(m[1].replace(/_/g, "")) });
        else if (m[2] !== undefined)
            out.push({ t: "id", v: m[2].toLowerCase() });
        else
            out.push({ t: "op", v: ({ "×": "*", "÷": "/", "−": "-", "**": "^" })[m[3]] || m[3] });
    }
    return out;
}

function factorial(n) {
    if (n < 0 || n !== Math.floor(n) || n > 170)
        return NaN;
    var r = 1;
    for (var i = 2; i <= n; i++)
        r *= i;
    return r;
}

function parse(tokens) {
    var i = 0;
    var ops = 0;
    function peek() { return tokens[i]; }
    function isOp(v) { var t = tokens[i]; return t && t.t === "op" && t.v === v; }
    function isId(v) { var t = tokens[i]; return t && t.t === "id" && t.v === v; }
    function fail() { throw new Error("parse"); }

    // expr := term (("+" | "-") term)*
    function expr() {
        var v = term();
        while (isOp("+") || isOp("-")) {
            var op = tokens[i++].v;
            ops++;
            var r = term();
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }
    // term := unary (("*" | "/" | "mod" | implicit) unary)*
    function term() {
        var v = unary();
        for (;;) {
            var t = peek();
            if (isOp("*") || isOp("/") || isId("mod")) {
                var op = tokens[i++].v;
                ops++;
                var r = unary();
                v = op === "*" ? v * r : op === "/" ? v / r : ((v % r) + r) % r;
            } else if (t && (t.t === "num" || (t.t === "id" && t.v !== "mod") || (t.t === "op" && t.v === "("))) {
                ops++;
                v *= unary();
            } else {
                return v;
            }
        }
    }
    // unary := ("-" | "+") unary | power   (so -2^2 = -4)
    function unary() {
        if (isOp("-") || isOp("+")) {
            var neg = tokens[i++].v === "-";
            ops++;
            var v = unary();
            return neg ? -v : v;
        }
        return power();
    }
    // power := postfix ("^" unary)?   (right-associative)
    function power() {
        var v = postfix();
        if (isOp("^")) {
            i++;
            ops++;
            return Math.pow(v, unary());
        }
        return v;
    }
    function postfix() {
        var v = atom();
        while (isOp("!") || isOp("%")) {
            v = tokens[i++].v === "!" ? factorial(v) : v / 100;
            ops++;
        }
        return v;
    }
    function atom() {
        var t = tokens[i++];
        if (!t)
            fail();
        if (t.t === "num")
            return t.v;
        if (t.t === "op" && t.v === "(") {
            var v = expr();
            if (!isOp(")"))
                fail();
            i++;
            return v;
        }
        if (t.t === "id") {
            if (fns.hasOwnProperty(t.v)) {
                ops++;
                // sqrt(2), sqrt 2 (binds tightly: sqrt 4 * 2 = 4)
                if (isOp("(")) {
                    i++;
                    var args = [expr()];
                    while (isOp(",")) {
                        i++;
                        args.push(expr());
                    }
                    if (!isOp(")"))
                        fail();
                    i++;
                    return fns[t.v].apply(null, args);
                }
                return fns[t.v](postfix());
            }
            if (consts.hasOwnProperty(t.v))
                return consts[t.v];
        }
        fail();
    }

    var v = expr();
    if (i !== tokens.length)
        fail();
    return { value: v, ops: ops };
}

// Trims float noise (0.1+0.2 -> 0.3) and avoids exponent notation for everyday sizes
function format(v) {
    if (Object.is(v, -0))
        v = 0;
    var r = Number(v.toPrecision(12));
    if (Math.abs(r) >= 1e21 || (r !== 0 && Math.abs(r) < 1e-9))
        return r.toExponential().replace("e+", "e");
    return String(r);
}

// { value, ops } for any expression (a bare number too), or null
function run(q) {
    if (q === "" || q.length > 200)
        return null;
    var tokens = tokenize(q);
    if (!tokens || tokens.length === 0)
        return null;
    try {
        var res = parse(tokens);
        return isFinite(res.value) ? res : null;
    } catch (e) {
        return null;
    }
}

function evaluate(query) {
    var res = run(query.trim().replace(/^=\s*/, ""));
    return res && res.ops > 0 ? format(res.value) : null;
}
