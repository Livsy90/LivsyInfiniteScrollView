# InfiniteScrollView

A generic SwiftUI component for infinite (looping) scrolling along a chosen axis. It mirrors the `ScrollView` API while adding item duplication and seamless position wrap-around to achieve a continuous loop.

<img src="https://github.com/Livsy90/LivsyInfiniteScrollView/blob/main/InfiniteScrollViewDemo.gif" height="450">
<img src="https://github.com/Livsy90/LivsyInfiniteScrollView/blob/main/InfiniteScrollViewDemo2.gif" height="450">

## How it works
`InfiniteScrollView` continuously renders your data and appends a calculated number of repeated items so that when the end is reached, scrolling smoothly continues from the beginning. During wrap-around, the component preserves the current scrolling velocity using a transaction, making the jump imperceptible to the user.

The component mirrors the core `ScrollView` API: it accepts a scroll axis and a `content` builder, and additionally requires `itemExtent` — the size of each item along the scroll axis — to correctly compute the number of duplicates.

## Key features
- Supports horizontal and vertical axes (`Axis.Set`).
- Infinite scrolling with seamless wrap-around.
- Preserves scrolling velocity during wrap-around.
- Simple integration: API is similar to standard `ScrollView`.

## Generic parameters
- `Collection`: A `RandomAccessCollection` whose elements are `Identifiable`. Used as the data source.
- `Content`: The `View` produced by the builder for each element.

## Important note about itemExtent
`itemExtent` is the size of an item along the selected axis: width for horizontal scrolling and height for vertical scrolling. It is not a `CGSize`. Provide a value that matches the actual rendered dimension along the scroll axis; otherwise, loop behavior may be incorrect.

## Requirements
- iOS 18+

## Installation

### Swift Package Manager (Xcode)
1. In Xcode, open your project settings.
2. Select the Package Dependencies tab.
3. Click the + button and paste the repository URL:
   https://github.com/Livsy90/LivsyInfiniteScrollView
4. Choose the latest version and add the package to your app target.
### Swift Package Manager (Package.swift)
Add the package to your dependencies:
```swift
.package(url: "https://github.com/Livsy90/LivsyInfiniteScrollView", branch: "main")
```

## Example

```swift
    struct Item: Identifiable { let id = UUID(); let index: Int }
    let dataSource = Array(1...10).map { Item(index: $0) }

    InfiniteScrollView(
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
```
```swift
    struct Item: Identifiable { let id = UUID(); let index: Int }
    let dataSource = Array(1...20).map { Item(index: $0) }

    InfiniteScrollView(
        axis: .vertical,
        spacing: 8,
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
```
