import SwiftUI

/// Uses ordinary SwiftUI scrolling; it does not observe or record input events.
struct ScrollTest: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Horizontal scroll test").font(.title2)
            Text("Move the pointer over the numbered strip. Hold the lower thumb and roll the wheel. Watch whether the strip moves. Use the bottom scrollbar to verify it can move.")
            Text("This tests visible application behavior. It does not identify the source of a scroll or record macOS events.").foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    ForEach(1...30, id: \.self) { number in
                        Text("Column \(number)")
                            .font(.headline)
                            .frame(width: 130, height: 120)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(8)
                    }
                }.padding()
            }.border(Color.secondary.opacity(0.4))
            Text("Try vertical wheel scrolling in another scrollable area separately. A stationary strip alone does not prove whether macOS emitted a scroll event.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding()
    }
}
