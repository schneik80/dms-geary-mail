import QtQuick
import qs.Common

// Run by DMS (>= 1.5) before the plugin loads. Passing null to done() lets the
// plugin load; passing {title, details} keeps it unloaded and shows a
// "Dank Geary Mail Startup Failed" toast. Older DMS ignores this file.
//
// The check runs the helper itself with counts only, so it fails for exactly
// the reasons the widget would: no python3, or no Geary configuration.
QtObject {
    readonly property string scriptPath: Qt.resolvedUrl("geary-unread.py").toString().replace("file://", "")

    function check(done) {
        Proc.runCommand("dankGearyMail.startupCheck",
            ["sh", "-c", 'command -v python3 >/dev/null || exit 127; exec python3 "$1" --recent 0', "sh", scriptPath],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    done(null)
                    return
                }
                if (exitCode === 127) {
                    done({
                        "title": "python3 is required",
                        "details": "Dank Geary Mail reads Geary's database with a small Python script. Install python3 and re-enable the plugin."
                    })
                    return
                }
                // The helper reports a missing Geary setup as JSON with an "error" field and exit 1.
                let reported = ""
                try {
                    reported = JSON.parse(stdout).error || ""
                } catch (e) {}
                if (reported) {
                    done({
                        "title": reported,
                        "details": "Dank Geary Mail reads Geary's local database. Install Geary (Flatpak org.gnome.Geary or native), add at least one account, then re-enable the plugin. Looked in ~/.var/app/org.gnome.Geary and ~/.config/geary."
                    })
                    return
                }
                done({
                    "title": "Dank Geary Mail helper failed",
                    "details": "geary-unread.py exited with code " + exitCode + " before producing a result. Run it by hand from the plugin directory to see why, or reinstall with: dms plugins update dankGearyMail"
                })
            })
    }
}
