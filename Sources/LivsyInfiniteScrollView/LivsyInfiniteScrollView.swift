import SwiftUI
internal import Combine

/// A generic, axis-aware, infinitely looping scroll view.
///
/// InfiniteScrollView renders your data contiguously and appends a calculated number of repeated items
/// to seamlessly wrap scrolling when the user reaches either edge. The component preserves the user's
/// scrolling velocity during wrap-around using a transaction, making the jump imperceptible.
///
/// The view mirrors the core API of ScrollView by accepting an axis and a content builder, while also
/// requiring an `itemExtent` (the size of each item along the scroll axis) to compute how many repeated
/// items are needed for a smooth loop.
///
/// - Generic Parameters:
///   - Collection: A RandomAccessCollection whose elements are Identifiable. Used as the data source.
///   - Content: The view type produced for each element.
///
/// - Note: `itemExtent` is the dimension along the selected axis (width for horizontal, height for vertical),
///   not a CGSize. Choose a value that matches the rendered item dimension to ensure correct loop behavior.
///
/// - Example:
/// ```swift
/// struct Item: Identifiable { let id = UUID(); let index: Int }
/// let dataSource = Array(1...8).map { Item(index: $0) }
///
/// // Horizontal loop
/// InfiniteScrollView(
///     axis: .horizontal,
///     spacing: 12,
///     scrollingSpeed: 0.7,
///     itemExtent: 100,
///     dataSource: dataSource
/// ) { item in
///     RoundedRectangle(cornerRadius: 12)
///         .fill(.blue)
///         .frame(height: 100)
///         .overlay { Text("\(item.index)") }
/// }
/// .frame(height: 120)
///
/// // Vertical loop
/// InfiniteScrollView(
///     axis: .vertical,
///     spacing: 8,
///     itemExtent: 56,
///     dataSource: dataSource
/// ) { item in
///     RoundedRectangle(cornerRadius: 10)
///         .fill(.green.opacity(0.6))
///         .overlay { Text("Row \(item.index)") }
/// }
/// ```
public struct InfiniteScrollView<Collection: RandomAccessCollection, Content: View>: View where Collection.Element: Identifiable {
    private let spacing: CGFloat
    private let scrollingSpeed: CGFloat
    private let itemExtent: CGFloat
    private let axis: Axis.Set
    private let dataSource: Collection

    @ViewBuilder private let content: (Collection.Element) -> Content

    @State private var scrollState: ScrollPosition = .init()
    @State private var viewportExtent: CGFloat = .zero
    @State private var axisOffset: CGFloat = .zero
    @State private var duplicateCount: Int = .zero

    /// Creates an infinitely looping scroll view.
    ///
    /// - Parameters:
    ///   - axis: The scroll axis. Use `.horizontal` or `.vertical`.
    ///   - spacing: Spacing between consecutive items.
    ///   - scrollingSpeed: Automatic scrolling speed per tick. Set to 0 to disable.
    ///   - itemExtent: The size of each item along the scroll axis (width for horizontal, height for vertical).
    ///   - dataSource: The data source to render.
    ///   - content: A view builder that produces the content for a given data element.
    ///
    /// - Example:
    /// ```swift
    /// struct Item: Identifiable { let id = UUID(); let index: Int }
    /// let dataSource = Array(1...10).map { Item(index: $0) }
    ///
    /// InfiniteScrollView(
    ///     axis: .horizontal,
    ///     spacing: 10,
    ///     scrollingSpeed: 0.7,
    ///     itemExtent: 100,
    ///     dataSource: dataSource
    /// ) { item in
    ///     Rectangle()
    ///         .fill(.blue)
    ///         .frame(height: 100)
    ///         .overlay { Text("\(item.index)") }
    /// }
    /// .frame(height: 120)
    /// ```
    ///
    /// ```swift
    /// // Vertical example
    /// InfiniteScrollView(
    ///     axis: .vertical,
    ///     spacing: 8,
    ///     itemExtent: 60,
    ///     dataSource: dataSource
    /// ) { item in
    ///     RoundedRectangle(cornerRadius: 12)
    ///         .fill(.green.opacity(0.5))
    ///         .overlay { Text("Row \(item.index)") }
    /// }
    /// ```
    public init(
        axis: Axis.Set = .horizontal,
        spacing: CGFloat = 10,
        scrollingSpeed: CGFloat = 0,
        itemExtent: CGFloat,
        dataSource: Collection,
        @ViewBuilder content: @escaping (Collection.Element) -> Content
    ) {
        self.axis = axis
        self.spacing = spacing
        self.scrollingSpeed = scrollingSpeed
        self.itemExtent = itemExtent
        self.dataSource = dataSource
        self.content = content
    }

    public var body: some View {
        ScrollView(axis) {
            ZStack {
                if axis == .horizontal {
                    HStack(spacing: spacing) {
                        HStack(spacing: spacing) {
                            ForEach(dataSource) { item in
                                content(item)
                                    .frame(width: itemExtent)
                            }
                        }

                        HStack(spacing: spacing) {
                            ForEach(0..<duplicateCount, id: \.self) { index in
                                let actualIndex = index % dataSource.count
                                let itemIndex = dataSource.index(dataSource.startIndex, offsetBy: actualIndex)

                                content(dataSource[itemIndex])
                                    .frame(width: itemExtent)
                            }
                        }
                    }
                } else {
                    VStack(spacing: spacing) {
                        VStack(spacing: spacing) {
                            ForEach(dataSource) { item in
                                content(item)
                                    .frame(height: itemExtent)
                            }
                        }

                        VStack(spacing: spacing) {
                            ForEach(0..<duplicateCount, id: \.self) { index in
                                let actualIndex = index % dataSource.count
                                let itemIndex = dataSource.index(dataSource.startIndex, offsetBy: actualIndex)

                                content(dataSource[itemIndex])
                                    .frame(height: itemExtent)
                            }
                        }
                    }
                }
            }
        }
        .scrollPosition($scrollState)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) {
            if axis == .horizontal {
                return $0.containerSize.width
            } else {
                return $0.containerSize.height
            }
        } action: { _, newValue in
            let measuredViewport = newValue
            let safeValue: Int = 1
            let neededCount = (measuredViewport / (itemExtent + spacing)).rounded()

            self.duplicateCount = Int(neededCount) + safeValue
            self.viewportExtent = measuredViewport
        }

        .onScrollGeometryChange(for: CGFloat.self) {
            if axis == .horizontal {
                return $0.contentOffset.x + $0.contentInsets.leading
            } else {
                return $0.contentOffset.y + $0.contentInsets.top
            }
        } action: { oldValue, newValue in
            axisOffset = newValue
            guard duplicateCount > 0 else { return }

            let itemsExtentSum = CGFloat(dataSource.count) * itemExtent
            let spacingSum = CGFloat(dataSource.count) * spacing
            let totalExtent = itemsExtentSum + spacingSum

            let wrapTargetOffset = min(totalExtent - newValue, 0)

            /// Resetting Scroll without disrupting ongoing scroll interaction using transaction
            if wrapTargetOffset < 0 || newValue < 0 {
                var transaction = Transaction()
                transaction.scrollPositionUpdatePreservesVelocity = true

                withTransaction(transaction) {
                    if newValue < 0 {
                        /// Backward reset
                        if axis == .horizontal {
                            scrollState.scrollTo(x: totalExtent)
                        } else {
                            scrollState.scrollTo(y: totalExtent)
                        }
                    } else {
                        /// Forward reset
                        if axis == .horizontal {
                            scrollState.scrollTo(x: wrapTargetOffset)
                        } else {
                            scrollState.scrollTo(y: wrapTargetOffset)
                        }
                    }
                }
            }
        }

        // Automatic Scrolling (set `scrollingSpeed` to 0 to disable)
        .onReceive(Timer.publish(every: 0.01, on: .main, in: .default).autoconnect()) { _ in
            guard scrollingSpeed != 0 else { return }
            if axis == .horizontal {
                scrollState.scrollTo(x: axisOffset + scrollingSpeed)
            } else {
                scrollState.scrollTo(y: axisOffset + scrollingSpeed)
            }
        }
    }
}

#Preview("InfiniteScrollView") {
    struct Item: Identifiable { let id = UUID(); let index: Int }
    let dataSource = Array(1...10).map { Item(index: $0) }

    return InfiniteScrollView(
        axis: .horizontal,
        spacing: 10,
        scrollingSpeed: 0.7,
        itemExtent: 100,
        dataSource: dataSource
    ) { item in
        Rectangle()
            .fill(.blue)
            .frame(height: 100)
            .overlay {
                Text("\(item.index)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
    }
    .frame(height: 120)
}

#Preview("InfiniteScrollView Vertical") {
    struct Item: Identifiable { let id = UUID(); let index: Int }
    let dataSource = Array(1...20).map { Item(index: $0) }

    return InfiniteScrollView(
        axis: .vertical,
        spacing: 8,
        scrollingSpeed: 0.0,
        itemExtent: 60,
        dataSource: dataSource
    ) { item in
        RoundedRectangle(cornerRadius: 12)
            .fill(.green.opacity(0.5))
            .overlay {
                Text("Row \(item.index)")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
            }
    }
}

