pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Launcher backend. Owns the app list, fuzzy matching, and (Task 5/6/7)
// calc + run-fallback + frecency. View layer is Launcher.qml.
Singleton {
    id: root

    // current search text, driven by the Field in Launcher.qml
    property string query: ""

    // computed result rows. Each row: { kind, label, sub, entry }
    //   kind: "app" | "calc" | "run"   (calc/run added in later tasks)
    //   entry: the DesktopEntry for "app" rows, else null
    property var results: computeResults()

    onQueryChanged: results = computeResults()

    // frecency: { "<appId>": { count: N, last: <epochMs> } }
    property var frecency: ({})

    // ensure the state dir + an empty history file exist before FileView reads
    Process {
        id: stateInitProc
        command: ["sh", "-c",
            "mkdir -p /home/segfault/.local/state/quickshell && " +
            "[ -f /home/segfault/.local/state/quickshell/launcher-frecency.json ] || " +
            "echo '{}' > /home/segfault/.local/state/quickshell/launcher-frecency.json"]
        Component.onCompleted: running = true
    }

    FileView {
        id: frecencyFile
        path: "/home/segfault/.local/state/quickshell/launcher-frecency.json"
        blockLoading: true
        printErrors: false        // first-run "missing file" is expected; we handle it

        onLoaded: {
            try { root.frecency = JSON.parse(frecencyFile.text() || "{}"); }
            catch (e) { root.frecency = ({}); }
            root.results = root.computeResults();
        }
        onLoadFailed: root.frecency = ({})
    }

    // frequency × recency. Recent + frequent apps score highest.
    function frecencyBoost(id) {
        var rec = root.frecency[id];
        if (!rec) return 0;
        var ageDays = (Date.now() - rec.last) / 86400000;
        var w = ageDays < 1 ? 4 : ageDays < 7 ? 2 : ageDays < 30 ? 1 : 0.5;
        return rec.count * w;
    }

    // --- app inventory -----------------------------------------------------
    // DesktopEntries.applications is an UntypedObjectModel; .values is the
    // JS array of DesktopEntry. Filter out noDisplay (hidden) entries.
    function apps() {
        var out = [];
        var vals = DesktopEntries.applications.values;
        for (var i = 0; i < vals.length; i++) {
            var e = vals[i];
            if (e && !e.noDisplay && e.name) out.push(e);
        }
        return out;
    }

    // --- fuzzy subsequence scorer -----------------------------------------
    // Returns -1 if `q` is not a subsequence of `t`, else a score where
    // contiguous runs and early/word-start matches score higher.
    function fuzzyScore(q, t) {
        q = q.toLowerCase();
        t = t.toLowerCase();
        if (q.length === 0) return 0;
        var ti = 0, score = 0, streak = 0, firstIdx = -1, prevIdx = -2;
        for (var qi = 0; qi < q.length; qi++) {
            var c = q.charAt(qi);
            var found = -1;
            for (; ti < t.length; ti++) {
                if (t.charAt(ti) === c) { found = ti; break; }
            }
            if (found === -1) return -1;
            if (firstIdx === -1) firstIdx = found;
            if (found === prevIdx + 1) { streak++; score += 5 + streak; }
            else { streak = 0; score += 1; }
            // word-start bonus (start of string or preceded by space/-/.)
            if (found === 0) score += 8;
            else {
                var pc = t.charAt(found - 1);
                if (pc === " " || pc === "-" || pc === ".") score += 4;
            }
            prevIdx = found;
            ti = found + 1;
        }
        score += Math.max(0, 10 - firstIdx);
        return score;
    }

    // --- calculator -------------------------------------------------------
    // calc is active iff the trimmed query is pure arithmetic AND has an
    // operator. Bare numbers ("2048") stay app-search.
    function isCalc(s) {
        var t = s.trim();
        if (t.length === 0) return false;
        if (!/^[0-9.+\-*/%() ]+$/.test(t)) return false;
        return /[+\-*/%]/.test(t);
    }

    // Shunting-yard → RPN → evaluate. Returns a Number or null on error.
    // No eval/Function (Qt V4 quirks). Unary minus handled via prevType.
    function evalCalc(s) {
        var t = s.trim();
        if (!/^[0-9.+\-*/%() ]+$/.test(t)) return null;
        var tokens = t.match(/(\d+\.?\d*|\.\d+|[+\-*/%()])/g);
        if (!tokens) return null;
        var prec = { "+": 1, "-": 1, "*": 2, "/": 2, "%": 2, "u-": 3 };
        var out = [], ops = [], prev = "op";  // "op" | "num" | ")"
        for (var i = 0; i < tokens.length; i++) {
            var tk = tokens[i];
            if (/^[\d.]/.test(tk)) { out.push(parseFloat(tk)); prev = "num"; }
            else if (tk === "(") { ops.push(tk); prev = "op"; }
            else if (tk === ")") {
                while (ops.length && ops[ops.length - 1] !== "(") out.push(ops.pop());
                if (!ops.length) return null;
                ops.pop();
                prev = ")";
            } else {
                var op = tk;
                if (op === "-" && (prev === "op")) op = "u-";   // unary minus
                while (ops.length) {
                    var top = ops[ops.length - 1];
                    if (top === "(") break;
                    if (prec[top] >= prec[op] && op !== "u-") out.push(ops.pop());
                    else break;
                }
                ops.push(op);
                prev = "op";
            }
        }
        while (ops.length) {
            var o = ops.pop();
            if (o === "(") return null;
            out.push(o);
        }
        var st = [];
        for (var j = 0; j < out.length; j++) {
            var x = out[j];
            if (typeof x === "number") { st.push(x); continue; }
            if (x === "u-") { if (!st.length) return null; st.push(-st.pop()); continue; }
            if (st.length < 2) return null;
            var b = st.pop(), a = st.pop();
            if (x === "+") st.push(a + b);
            else if (x === "-") st.push(a - b);
            else if (x === "*") st.push(a * b);
            else if (x === "/") st.push(a / b);
            else if (x === "%") st.push(a % b);
        }
        if (st.length !== 1) return null;
        var r = st[0];
        if (typeof r !== "number" || !isFinite(r)) return null;
        return Math.round(r * 1e6) / 1e6;   // trim float noise
    }

    // --- result computation (Task 1: apps only, alpha-tiebreak) -----------
    function computeResults() {
        var q = root.query.trim();
        if (q.length === 0) return [];   // empty until you type
        if (isCalc(q)) {
            var v = evalCalc(q);
            if (v === null) return [];
            return [{ kind: "calc", label: String(v), sub: "= copy", entry: null }];
        }
        var list = apps();
        var scored = [];
        for (var i = 0; i < list.length; i++) {
            var e = list[i];
            var s = fuzzyScore(q, e.name);
            if (s < 0) continue;
            scored.push({ kind: "app", label: e.name, sub: e.comment || "",
                          entry: e, score: s + frecencyBoost(e.id) * 3 });
        }
        scored.sort(function (a, b) {
            if (b.score !== a.score) return b.score - a.score;
            return a.label.localeCompare(b.label);
        });
        if (scored.length === 0 && q.length > 0) {
            return [{ kind: "run", label: "» run: " + q, sub: "", entry: null,
                      cmd: q }];
        }
        return scored;
    }

    // --- actions -----------------------------------------------------------
    function launch(row) {
        if (!row || !row.entry) return;
        var id = row.entry.id;
        var rec = root.frecency[id] || { count: 0, last: 0 };
        rec.count += 1;
        rec.last = Date.now();
        root.frecency[id] = rec;
        frecencyFile.setText(JSON.stringify(root.frecency));
        row.entry.execute();
    }

    Process { id: copyProc }
    function copy(text) {
        copyProc.command = ["wl-copy", "--", String(text)];
        copyProc.running = true;
    }

    Process { id: runProc }
    function run(cmd) {
        runProc.command = ["sh", "-c", String(cmd)];
        runProc.running = true;
    }
}
