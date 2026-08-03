import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// Dark translucent rectangle (kitty-bg tone) with two bare inputs.
//
// greetd auth is a PAM *conversation*, not a per-keypress thing. We buffer the
// password and drive the conversation from the authMessage signal:
//   submit() → createSession(user) → greetd emits authMessage("Password:") →
//   we auto-respond with the buffered password → readyToLaunch → launch niri.
// So the whole flow is: [type user] Enter, [type pass] Enter. With the
// remembered username it's just: [type pass] Enter.
Rectangle {
    id: box

    width: 360
    height: 180
    radius: 0
    color: Theme.boxFill

    // Wrong-password shake. Translate (not anchors) so it doesn't fight the
    // horizontalCenter anchor Greeter sets on us; ±14px stays inside boxSlot's
    // 40px slack. Fired from onAuthFailure.
    transform: Translate { id: shakeT }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shakeT; property: "x"; to:  14; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; to:   9; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; to:  -6; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; to:   0; duration: 45 }
    }

    property string statusText: ""
    property color  statusColor: Theme.muted
    // Set during onCompleted from the persisted last-user file. Drives
    // focusInitial() so the field focused after Greeter reveals is the
    // right one (password when the user is remembered, else username).
    property bool   rememberedUser: false

    // Begin (or restart) the PAM conversation. Idempotent-ish: only kicks off
    // a new session when greetd is idle. onAuthMessage does the actual respond.
    function submit() {
        if (userInput.text.length === 0) {
            userInput.forceActiveFocus()
            return
        }
        if (!Greetd.available) {
            box.statusText = "greetd unavailable (preview)"
            box.statusColor = Theme.muted
            return
        }
        box.statusText = ""
        if (Greetd.state === GreetdState.Inactive) {
            Greetd.createSession(userInput.text)
        }
    }

    // Called by Greeter on first reveal (no keystroke yet) — just focus the
    // right field for the user to type into.
    function focusInitial() {
        if (rememberedUser) passInput.forceActiveFocus()
        else                userInput.forceActiveFocus()
    }

    // Preview-mode escape hatch. In production (greetd active) Esc is a no-op
    // so an idle keypress doesn't drop the user back to nothing.
    Keys.onEscapePressed: if (!Greetd.available) Qt.quit()

    // Pop-out before launching the session. greetd warns the greeter to exit
    // ASAP after launch, so animate first then fire launch onFinished.
    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: box; property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
        NumberAnimation { target: box; property: "scale";   to: 0.96; duration: 150; easing.type: Easing.InCubic }
        // niri-session = standard wrapper from /usr/share/wayland-sessions/niri.desktop.
        // Do NOT wrap in `sh -c` — greetd execs the session directly and the
        // wrapper made it exit immediately (bounced back to the greeter).
        // Transition flicker is handled at the console level, not here.
        onFinished: if (Greetd.available) Greetd.launch(["niri-session"])
    }

    // Persisted last-known username. World-readable, written by the greeter
    // user only — the install step `chowns` /var/cache/quickshell-greeter to
    // greeter:greeter. Missing file on first run is normal (printErrors: false).
    FileView {
        id: lastUserFile
        path: "/var/cache/quickshell-greeter/last-user"
        blockLoading: true   // we read on startup before windows are up; safe per docs
        printErrors: false
    }

    // No initial focus or appearAnim — Greeter drives both via the collapsing
    // slot (clock-first reveal). We only stash the remembered user here so
    // focusInitial() knows which field to target.
    Component.onCompleted: {
        const remembered = lastUserFile.text().trim()
        if (remembered.length > 0) {
            userInput.text = remembered
            rememberedUser = true
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 22
        width: parent.width - 56

        // hostname strip — small, dim, restored.
        Text {
            width: parent.width
            text: "celestia"
            color: Theme.muted
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
        }

        Field {
            id: userInput
            width: parent.width
            textColor: Theme.accentText   // login = accent purple
            // Enter on username just advances to password (unless it's already
            // filled, then submit straight away).
            onAccepted: {
                if (passInput.text.length > 0) box.submit()
                else passInput.forceActiveFocus()
            }
        }

        Field {
            id: passInput
            width: parent.width
            password: true
            textColor: Theme.fg            // password = fg
            onAccepted: box.submit()
        }

        // Tab cycles user → password → user. Wired post-construction because
        // KeyNavigation targets must be the inner TextInputs, not the Field wrappers.
        Component.onCompleted: {
            userInput.input.KeyNavigation.tab     = passInput.input
            userInput.input.KeyNavigation.backtab = passInput.input
            passInput.input.KeyNavigation.tab     = userInput.input
            passInput.input.KeyNavigation.backtab = userInput.input
        }

        // Status only when there's something to say — otherwise it would
        // reserve vertical space and push the fields off-center.
        Text {
            width: parent.width
            visible: text.length > 0
            text: box.statusText
            color: box.statusColor
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
        }
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (error) {
                box.statusText = message
                box.statusColor = Theme.warn
            }
            if (!responseRequired) return
            // Drive the PAM conversation: echo prompt → username, secret → password.
            // This is what makes login a single Enter instead of step-by-step.
            Greetd.respond(echoResponse ? userInput.text : passInput.text)
        }
        function onAuthFailure(message) {
            // PAM's message here is usually blank or a terse "Login incorrect";
            // show a clear line of our own and shake the box.
            box.statusText = "incorrect password"
            box.statusColor = Theme.warn
            shakeAnim.restart()
            passInput.clear()
            Greetd.cancelSession()
            // Refocus the password field (username is remembered/filled), not
            // the username — the failure is almost always a mistyped password.
            if (box.rememberedUser) passInput.forceActiveFocus()
            else                    userInput.forceActiveFocus()
        }
        function onReadyToLaunch() {
            // Remember the username for next time, then animate out;
            // exitAnim.onFinished fires Greetd.launch.
            // niri-session = the standard wrapper from /usr/share/wayland-sessions/niri.desktop.
            if (userInput.text !== lastUserFile.text().trim()) {
                lastUserFile.setText(userInput.text)
            }
            exitAnim.start()
        }
        function onError(err) {
            box.statusText = err
            box.statusColor = Theme.warn
        }
    }
}
