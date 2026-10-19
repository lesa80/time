import AppKit

@MainActor
extension AppDelegate {
    func addPulsarMenuItems(to menu: NSMenu) {
        add("pulsarTime", L("Show time"), #selector(illuminatePulsar), to: menu)
        add("pulsarSeconds", L("Show seconds"), #selector(showPulsarSeconds), to: menu)
        add("pulsarOff", L("Turn off display"), #selector(extinguishPulsar), to: menu)
    }
    func updatePulsarMenu() {
        for key in ["pulsarTime", "pulsarSeconds", "pulsarOff"] {
            menuActions[key]?.isHidden = !renderer.isPulsar
        }
        menuActions["pulsarOff"]?.isEnabled = pulsar.reading.isLit
    }
    func finishPulsarInteraction() {
        lastAccessibilitySecond = -1
        updateChronographMenu()
        if clockView != nil && window != nil { startTimer() }
    }
    @objc func illuminatePulsar() {
        guard renderer.isPulsar else { return }
        pulsar.illuminate()
        finishPulsarInteraction()
    }
    @objc func showPulsarSeconds() {
        guard renderer.isPulsar else { return }
        pulsar.illuminate(seconds: true)
        finishPulsarInteraction()
    }
    @objc func extinguishPulsar() {
        guard renderer.isPulsar else { return }
        pulsar.cancel()
        finishPulsarInteraction()
    }
}
