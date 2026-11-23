import SwiftUI
import WidgetKit

// Home-screen widget. The app sends the texts already formatted (see
// lib/core/utils/phone_widget.dart) through the App Group below; this only
// lays them out with the chosen colors. Setup steps: ios/FinanceWidget/README.md

private let appGroupId = "group.io.github.carlosmartinezdev20.appgastos"

struct FinanceEntry: TimelineEntry {
  let date: Date
  let theme: String
  /// The colors resolved for the app's accent (#AARRGGBB); nil in data saved
  /// by versions without accents, which use the table in WidgetColors.
  let sentColors: [String: String]?
  let title: String
  let amount: String
  let caption: String
  let progress: Int
  let bars: [Double]

  static let placeholder = FinanceEntry(
    date: Date(), theme: "dark", sentColors: nil, title: "Balance disponible", amount: "$232.96",
    caption: "Gastos 30 días: $70.54", progress: -1,
    bars: [0.2, 0.4, 1, 0.1, 0.1, 0.1, 0.3])

  static func load() -> FinanceEntry {
    let data = UserDefaults(suiteName: appGroupId)
    return FinanceEntry(
      date: Date(),
      theme: data?.string(forKey: "theme") ?? "dark",
      sentColors: {
        var colors: [String: String] = [:]
        for key in ["background", "foreground", "muted", "highlight"] {
          guard let value = data?.string(forKey: key) else { return nil }
          colors[key] = value
        }
        return colors
      }(),
      title: data?.string(forKey: "title") ?? "Finanzas",
      amount: data?.string(forKey: "amount") ?? "—",
      caption: data?.string(forKey: "caption") ?? "Abre la app para ver tus datos",
      progress: data?.object(forKey: "progress") as? Int ?? -1,
      bars: (data?.string(forKey: "bars") ?? "")
        .split(separator: ",").compactMap { Double($0) })
  }
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> FinanceEntry { .placeholder }

  func getSnapshot(in context: Context, completion: @escaping (FinanceEntry) -> Void) {
    completion(context.isPreview ? .placeholder : .load())
  }

  // The app reloads the timeline whenever its data changes.
  func getTimeline(in context: Context, completion: @escaping (Timeline<FinanceEntry>) -> Void) {
    completion(Timeline(entries: [.load()], policy: .never))
  }
}

/// The colors the app sent, or, for data saved by versions without accents,
/// the same values as PhoneWidgetTheme with Lima in Dart.
struct WidgetColors {
  let background: Color
  let foreground: Color
  let muted: Color
  let highlight: Color

  init(_ entry: FinanceEntry) {
    if let sent = entry.sentColors,
      let background = Color(argbHex: sent["background"]),
      let foreground = Color(argbHex: sent["foreground"]),
      let muted = Color(argbHex: sent["muted"]),
      let highlight = Color(argbHex: sent["highlight"])
    {
      (self.background, self.foreground, self.muted, self.highlight) =
        (background, foreground, muted, highlight)
      return
    }
    switch entry.theme {
    case "light":
      (background, foreground, muted, highlight) =
        (Color(hex: 0xFFFFFF), Color(hex: 0x1C1C1E), Color(hex: 0x64646D), Color(hex: 0x8DBF1F))
    case "lime":
      (background, foreground, muted, highlight) =
        (Color(hex: 0xC8F04B), Color(hex: 0x1A2006), Color(hex: 0x4A5A1C), Color(hex: 0x1A2006))
    case "lilac":
      (background, foreground, muted, highlight) =
        (Color(hex: 0xE2DDFF), Color(hex: 0x514578), Color(hex: 0x7A6FA3), Color(hex: 0x514578))
    default:
      (background, foreground, muted, highlight) =
        (Color(hex: 0x1C1C1E), Color(hex: 0xF7F7F8), Color(hex: 0xA1A1A8), Color(hex: 0xC8F04B))
    }
  }
}

extension Color {
  /// "#AARRGGBB", as the app sends it.
  init?(argbHex: String?) {
    guard let argbHex, argbHex.hasPrefix("#"), argbHex.count == 9,
      let value = UInt32(argbHex.dropFirst(), radix: 16)
    else { return nil }
    self.init(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255,
      opacity: Double((value >> 24) & 0xFF) / 255)
  }

  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

struct FinanceWidgetView: View {
  let entry: FinanceEntry

  var body: some View {
    let colors = WidgetColors(entry)
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        Image(systemName: "dollarsign.circle").font(.caption)
          .foregroundColor(colors.foreground)
        Text(entry.title).font(.caption.weight(.semibold))
          .foregroundColor(colors.muted).lineLimit(1)
      }
      Text(entry.amount)
        .font(.system(size: 26, weight: .heavy, design: .rounded))
        .foregroundColor(colors.foreground)
        .minimumScaleFactor(0.5).lineLimit(1)
        .padding(.top, 4)
      Text(entry.caption).font(.caption2)
        .foregroundColor(colors.muted).lineLimit(2)
      Spacer(minLength: 6)
      if entry.progress >= 0 {
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(colors.foreground.opacity(0.12))
            Capsule().fill(colors.highlight)
              .frame(width: max(8, geo.size.width * CGFloat(entry.progress) / 100))
          }
        }
        .frame(height: 8)
      } else if !entry.bars.isEmpty {
        HStack(alignment: .bottom, spacing: 4) {
          ForEach(Array(entry.bars.enumerated()), id: \.offset) { index, value in
            RoundedRectangle(cornerRadius: 4)
              .fill(index == entry.bars.count - 1
                ? colors.highlight : colors.foreground.opacity(0.22))
              .frame(height: 30 * CGFloat(max(0.1, min(1, value))))
          }
        }
        .frame(height: 30, alignment: .bottom)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetBackground(colors.background)
  }
}

extension View {
  /// iOS 17 needs the background as a container background.
  @ViewBuilder func widgetBackground(_ color: Color) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      padding().background(color)
    }
  }
}

@main
struct FinanceWidget: Widget {
  // Must match PhoneWidgetService.iOSKind in Dart.
  let kind = "FinanceWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      FinanceWidgetView(entry: entry)
    }
    .configurationDisplayName("Finanzas")
    .description("Tu balance, el gasto de la semana o tu meta, con el color que elijas en la app.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
