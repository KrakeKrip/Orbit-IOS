import SwiftUI

extension OrbitAppearance {
    static func systemLight(_ raw: String) -> Self { raw == Self.ivory.rawValue ? .ivory : .light }
    static func systemDark(_ raw: String) -> Self { raw == Self.oled.rawValue ? .oled : .dark }
    static func systemTheme(scheme: ColorScheme, light: String, dark: String) -> Self {
        scheme == .dark ? systemDark(dark) : systemLight(light)
    }
}

/// Keep the native scheme automatic in system mode; resolve only Orbit's palette.
/// Reading the inherited scheme here avoids pinning the app to yesterday's mode.
struct OrbitTheme: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @AppStorage("orbit.ui.appearance") private var modeRaw = OrbitAppearance.system.rawValue
    @AppStorage("orbit.ui.appearance.systemLight") private var lightRaw = OrbitAppearance.light.rawValue
    @AppStorage("orbit.ui.appearance.systemDark") private var darkRaw = OrbitAppearance.dark.rawValue
    private var mode: OrbitAppearance { OrbitAppearance(rawValue: modeRaw) ?? .system }
    private var palette: OrbitAppearance {
        mode == .system ? .systemTheme(scheme: scheme, light: lightRaw, dark: darkRaw) : mode
    }
    func body(content: Content) -> some View {
        content
            .background(palette.canvas.ignoresSafeArea())
            .environment(\.orbitAppearance, palette)
            .preferredColorScheme(mode.colorScheme)
    }
}
