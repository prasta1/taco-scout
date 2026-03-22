import WidgetKit
import SwiftUI

@main
struct TacoScoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        TacoScoutWidget()
    }
}

struct TacoScoutWidget: Widget {
    let kind = "TacoScoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TacoWidgetProvider()) { entry in
            TacoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nearby Tacos")
        .description("See top-rated taco spots near you.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TacoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TacoWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumTacoWidgetView(entry: entry)
        default:
            SmallTacoWidgetView(entry: entry)
        }
    }
}
