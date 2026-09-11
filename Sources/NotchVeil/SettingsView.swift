import SwiftUI
import NotchVeilCore

private let ink = Color(red: 0.10, green: 0.15, blue: 0.14)
private let muted = Color(red: 0.43, green: 0.48, blue: 0.46)
private let accent = Color(red: 0.15, green: 0.40, blue: 0.31)
private let paper = Color(red: 0.96, green: 0.97, blue: 0.95)

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var previewHidden = true
    var quit: () -> Void
    private var copy: Localization { model.localization }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(accent).frame(width: 48, height: 48)
                        Image(systemName: "macbook").font(.system(size: 23, weight: .medium)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy.text(.appName)).font(.system(size: 25, weight: .semibold))
                        Text("NOTCHVEIL").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2.5).foregroundStyle(muted)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(model.errorMessage != nil ? .orange : (model.enabled ? accent : muted)).frame(width: 6, height: 6)
                        Text(model.statusTitle).font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.white.opacity(0.8), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.text(.tagline)).font(.system(size: 30, weight: .semibold))
                    Text(copy.text(.subtitle)).font(.system(size: 13)).foregroundStyle(muted)
                }

                VStack(spacing: 13) {
                    HStack {
                        Text(copy.text(.preview)).font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
                        Spacer()
                        HStack(spacing: 3) {
                            previewButton(copy.text(.before), hidden: false)
                            previewButton(copy.text(.after), hidden: true)
                        }.padding(3).background(.black.opacity(0.04), in: Capsule())
                    }
                    MonitorPreview(hidden: previewHidden, rounded: model.settings.roundedCorners,
                                   radius: model.settings.radius, extraHeight: model.settings.extraHeight, copy: copy)
                        .frame(height: 176)
                    Text(copy.text(.previewNote))
                        .font(.system(size: 10)).foregroundStyle(muted)
                }
                .padding(18).background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 18))

                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(copy.text(.enableVeil)).font(.system(size: 15, weight: .semibold))
                            Text(copy.text(.staticCopyNote))
                                .font(.system(size: 11)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle(copy.text(.enableVeil), isOn: Binding(get: { model.enabled }, set: { model.setEnabled($0) }))
                            .toggleStyle(.switch).labelsHidden().tint(accent)
                            .accessibilityIdentifier("enableVeil")
                    }.padding(18)
                    Divider().padding(.horizontal, 18)
                    HStack {
                        Label(copy.text(.displayScope), systemImage: "display.2").font(.system(size: 12))
                        Spacer()
                        Picker(copy.text(.displayScope), selection: $model.settings.scope) {
                            ForEach(DisplayScope.allCases, id: \.self) { scope in Text(scope.title(using: copy)).tag(scope) }
                        }.pickerStyle(.segmented).frame(width: 265).labelsHidden()
                    }.padding(18)
                    Divider().padding(.horizontal, 18)
                    HStack {
                        Label(copy.text(.roundedCorners), systemImage: "viewfinder").font(.system(size: 12))
                        Spacer()
                        Slider(value: $model.settings.radius, in: 0...32, step: 1).frame(width: 115)
                            .disabled(!model.settings.roundedCorners).accessibilityLabel(copy.text(.cornerRadius))
                        Text("\(Int(model.settings.radius)) pt").font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(muted).frame(width: 44, alignment: .trailing)
                        Toggle(copy.text(.roundedCorners), isOn: $model.settings.roundedCorners)
                            .toggleStyle(.switch).labelsHidden().controlSize(.small).tint(accent)
                    }.padding(18)
                    Divider().padding(.horizontal, 18)
                    HStack {
                        Label(copy.text(.extraHeight), systemImage: "arrow.up.and.down").font(.system(size: 12))
                        Spacer()
                        Text(copy.text(.automaticPlus)).font(.system(size: 11)).foregroundStyle(muted)
                        Slider(value: $model.settings.extraHeight, in: 0...20, step: 1).frame(width: 115)
                            .accessibilityLabel(copy.text(.extraHeightAccessibility))
                        Text("\(Int(model.settings.extraHeight)) pt").font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(muted).frame(width: 44, alignment: .trailing)
                    }.padding(18)
                }.background(.white, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(copy.text(.language), systemImage: "globe").font(.system(size: 12))
                        Spacer()
                        Picker(copy.text(.language), selection: $model.language) {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Text(language.title(using: copy)).tag(language)
                            }
                        }.pickerStyle(.segmented).frame(width: 300).labelsHidden()
                            .accessibilityIdentifier("interfaceLanguage")
                    }
                    Text(copy.text(.languageNote)).font(.system(size: 11)).foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(copy.text(.connectedDisplays)).font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
                        Spacer()
                        Button(copy.text(.refresh)) { model.refresh() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(accent)
                    }
                    ForEach(model.displays) { display in
                        HStack(spacing: 9) {
                            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display").frame(width: 19)
                            Text(model.displayName(display)).lineLimit(1)
                            Spacer()
                            Text(display.hasNotch ? copy.format(.notchHeight, Int(display.safeTop)) : copy.text(.noNotch)).foregroundStyle(muted)
                            Text(model.applied.contains(display.id) ? copy.text(.applied) : (display.isIncluded(in: model.settings.scope) ? copy.text(.selected) : copy.text(.unselected)))
                                .foregroundStyle(display.isIncluded(in: model.settings.scope) ? accent : muted)
                        }.font(.system(size: 11))
                    }
                    if model.selectedCount == 0 {
                        Text(copy.text(.noDisplays))
                            .font(.system(size: 11)).foregroundStyle(muted)
                    }
                }

                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11)).foregroundStyle(Color(red: 0.60, green: 0.29, blue: 0.10))
                        .fixedSize(horizontal: false, vertical: true).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.text(.restoreNote))
                    Text(copy.text(.dynamicRestoreNote))
                    Text(copy.text(.compatibilityNote))
                }.font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(copy.text(.privacyNote)).font(.system(size: 10)).foregroundStyle(muted)
                    Spacer()
                    Button(copy.text(.restoreAndQuit), action: quit).buttonStyle(.plain).foregroundStyle(accent).font(.system(size: 11, weight: .medium))
                }
            }
            .padding(28)
        }
        .background(paper).foregroundStyle(ink).tint(accent)
        .frame(width: 620)
        .preferredColorScheme(.light)
        .environment(\.locale, copy.locale)
    }

    private func previewButton(_ title: String, hidden: Bool) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.22)) { previewHidden = hidden } } label: {
            Text(title).font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 13).padding(.vertical, 5)
                .background(previewHidden == hidden ? .white : .clear, in: Capsule())
        }.buttonStyle(.plain).accessibilityLabel(copy.format(.previewAccessibility, title))
    }
}

struct MonitorPreview: View {
    var hidden: Bool
    var rounded: Bool
    var radius: Double
    var extraHeight: Double
    var copy: Localization
    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 26, 350.0)
            let height = 162.0
            let bar = 15.0 + (hidden ? extraHeight * 0.28 : 0)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.14, green: 0.17, blue: 0.16))
                    .frame(width: width + 10, height: height + 10).offset(y: -5)
                ZStack(alignment: .top) {
                    ZStack {
                        LinearGradient(colors: [Color(red: 0.70, green: 0.81, blue: 0.71),
                                                Color(red: 0.38, green: 0.59, blue: 0.52),
                                                Color(red: 0.15, green: 0.33, blue: 0.28)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Ellipse().fill(.white.opacity(0.18)).frame(width: 480, height: 200).rotationEffect(.degrees(-27)).offset(x: -90, y: -55)
                        Ellipse().fill(accent.opacity(0.40)).frame(width: 440, height: 160).rotationEffect(.degrees(-25)).offset(x: 80, y: 85)
                    }.frame(width: width, height: height).clipped()
                    if hidden {
                        Rectangle().fill(.black).frame(height: bar)
                        if rounded {
                            CornerMask(radius: radius * 0.35).fill(.black, style: FillStyle(eoFill: true))
                                .frame(height: height - bar).offset(y: bar)
                        }
                    } else {
                        Rectangle().fill(.white.opacity(0.15)).frame(height: bar)
                    }
                    HStack(spacing: 9) {
                        Image(systemName: "apple.logo").font(.system(size: 7))
                        Text("Finder").bold()
                        Text(copy.text(.previewMenus))
                        Spacer()
                        Image(systemName: "wifi")
                        Image(systemName: "battery.100percent")
                        Text(copy.text(.previewDate))
                    }.font(.system(size: 6)).foregroundStyle(hidden ? .white : ink)
                        .padding(.horizontal, 10).frame(height: 15)
                    UnevenNotch().fill(.black).frame(width: 62, height: 12)
                    Text(hidden ? copy.text(.previewQuiet) : copy.text(.previewWallpaper))
                        .font(.system(size: 15, weight: .light)).foregroundStyle(.white.opacity(0.85)).offset(y: 83)
                }.frame(width: width, height: height).clipShape(RoundedRectangle(cornerRadius: 6))
                RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.58, green: 0.62, blue: 0.60))
                    .frame(width: width + 39, height: 5).offset(y: height + 5)
            }.frame(maxWidth: .infinity).padding(.top, 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hidden ? copy.text(.previewHiddenAccessibility) : copy.text(.previewOriginalAccessibility))
    }
}

private struct UnevenNotch: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: CGRect(x: 0, y: -6, width: rect.width, height: rect.height + 6), cornerRadius: 4)
    }
}

private struct CornerMask: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
        return path
    }
}
