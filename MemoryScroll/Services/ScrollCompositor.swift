//
//  ScrollCompositor.swift
//  MemoryScroll
//
//  Created by Lixing Liu on 4/8/26.
//

import UIKit

/// Composites an array of ScrollPhotos into a single long strip image,
/// laid out either horizontally or vertically.
struct ScrollCompositor {

    struct Config {
        var orientation: ScrollOrientation = .vertical
        var stripSize: CGFloat = 800        // height for horizontal, width for vertical
        var spacing: CGFloat = 0
        var backgroundColor: UIColor = .black

        // Date overlay
        var showDate: Bool = true
        var dateFormat: String = "MMM d, yyyy"
        var dateFont: UIFont = .monospacedSystemFont(ofSize: 20, weight: .semibold)
        var dateColor: UIColor = .white
        var datePadding: CGFloat = 16
        var datePillInset: CGFloat = 8
        var dateBackgroundColor: UIColor = UIColor.black.withAlphaComponent(0.5)
        var dateCornerRadius: CGFloat = 6

        // Location overlay — shares font/color/pill style with the date stamp
        var showLocation: Bool = false

        // Per-photo crop bounds keyed by ScrollPhoto.id
        var cropBounds: [String: CropBounds] = [:]
    }

    // MARK: - Public

    static func composite(photos: [ScrollPhoto], config: Config = Config()) -> UIImage? {
        guard !photos.isEmpty else { return nil }

        switch config.orientation {
        case .horizontal:
            return compositeHorizontal(photos: photos, config: config)
        case .vertical:
            return compositeVertical(photos: photos, config: config)
        }
    }

    // MARK: - Horizontal Layout

    private static func compositeHorizontal(photos: [ScrollPhoto], config: Config) -> UIImage? {
        let dateFormatter = makeDateFormatter(config)

        struct Slot {
            let photo: ScrollPhoto
            let fullWidth: CGFloat   // width at full (uncropped) height
            let bounds: CropBounds
            let stripSize: CGFloat
            // Visible height after top+bottom trim
            var visibleHeight: CGFloat { stripSize * (1 - bounds.top - bounds.bottom) }
            // Actual draw width scales with the visible height
            var drawWidth: CGFloat { visibleHeight * photo.aspectRatio }
        }

        let slots: [Slot] = photos.map { photo in
            let bounds = config.cropBounds[photo.id] ?? .zero
            return Slot(photo: photo, fullWidth: config.stripSize * photo.aspectRatio,
                        bounds: bounds, stripSize: config.stripSize)
        }

        let totalWidth = slots.reduce(CGFloat(0)) { $0 + $1.drawWidth }
            + config.spacing * CGFloat(max(0, slots.count - 1))
        let size = CGSize(width: totalWidth, height: config.stripSize)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            config.backgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            var x: CGFloat = 0
            for slot in slots {
                // Center the cropped window vertically within the strip height
                let topTrim    = config.stripSize * slot.bounds.top
                let visH       = slot.visibleHeight
                let yOffset    = (config.stripSize - visH) / 2
                let rect       = CGRect(x: x, y: yOffset, width: slot.drawWidth, height: visH)

                // Draw the full image but shifted so the correct portion shows in rect
                let fullH      = config.stripSize
                let imageRect  = CGRect(x: x, y: yOffset - topTrim, width: slot.drawWidth, height: fullH)
                drawImageInRect(slot.photo.image, imageRect: imageRect, clipRect: rect, context: ctx.cgContext)

                if config.showDate {
                    drawDateStamp(date: slot.photo.creationDate, formatter: dateFormatter, in: rect, config: config)
                }
                if config.showLocation {
                    drawLocationStamp(locationName: slot.photo.locationName, in: rect, config: config)
                }
                x += slot.drawWidth + config.spacing
            }
        }
    }

    // MARK: - Vertical Layout

    private static func compositeVertical(photos: [ScrollPhoto], config: Config) -> UIImage? {
        let dateFormatter = makeDateFormatter(config)

        struct Slot {
            let photo: ScrollPhoto
            let bounds: CropBounds
            let fullHeight: CGFloat  // height at full (uncropped) size
            // Visible height after top+bottom trim
            var visibleHeight: CGFloat { fullHeight * (1 - bounds.top - bounds.bottom) }
        }

        let slots: [Slot] = photos.map { photo in
            let bounds = config.cropBounds[photo.id] ?? .zero
            return Slot(photo: photo, bounds: bounds, fullHeight: config.stripSize / photo.aspectRatio)
        }

        let totalHeight = slots.reduce(CGFloat(0)) { $0 + $1.visibleHeight }
            + config.spacing * CGFloat(max(0, slots.count - 1))
        let size = CGSize(width: config.stripSize, height: totalHeight)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            config.backgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            var y: CGFloat = 0
            for slot in slots {
                let topTrim   = slot.fullHeight * slot.bounds.top
                let visH      = slot.visibleHeight
                let rect      = CGRect(x: 0, y: y, width: config.stripSize, height: visH)

                // Draw full-height image but shifted upward so the correct band is visible
                let imageRect = CGRect(x: 0, y: y - topTrim, width: config.stripSize, height: slot.fullHeight)
                drawImageInRect(slot.photo.image, imageRect: imageRect, clipRect: rect, context: ctx.cgContext)

                if config.showDate {
                    drawDateStamp(date: slot.photo.creationDate, formatter: dateFormatter, in: rect, config: config)
                }
                if config.showLocation {
                    drawLocationStamp(locationName: slot.photo.locationName, in: rect, config: config)
                }
                y += visH + config.spacing
            }
        }
    }

    // MARK: - Drawing Helpers

    private static func makeDateFormatter(_ config: Config) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = config.dateFormat
        return f
    }

    /// Draws `image` scaled to fill `imageRect`, clipped to `clipRect`.
    /// The caller positions imageRect so the desired photo region aligns with clipRect.
    private static func drawImageInRect(
        _ image: UIImage,
        imageRect: CGRect,
        clipRect: CGRect,
        context: CGContext
    ) {
        guard let cgImage = image.cgImage else { return }

        // Scale imageRect to aspect-fill clipRect while preserving the caller's
        // positioning intent (top/bottom crop offset is already baked into imageRect.origin).
        let imageAspect = image.size.width / image.size.height
        let slotAspect  = imageRect.width / imageRect.height

        var drawRect = imageRect
        if imageAspect > slotAspect {
            // Image wider than slot: expand width to fill, keep height
            let scaledWidth = imageRect.height * imageAspect
            drawRect = CGRect(
                x: imageRect.midX - scaledWidth / 2,
                y: imageRect.minY,
                width: scaledWidth,
                height: imageRect.height
            )
        } else if imageAspect < slotAspect {
            // Image taller than slot: expand height to fill, keep width
            let scaledHeight = imageRect.width / imageAspect
            drawRect = CGRect(
                x: imageRect.minX,
                y: imageRect.midY - scaledHeight / 2,
                width: imageRect.width,
                height: scaledHeight
            )
        }

        context.saveGState()
        context.clip(to: [clipRect])
        // CGContext has a flipped coordinate system; compensate with a vertical flip.
        let flipY = drawRect.minY + drawRect.height
        context.translateBy(x: 0, y: flipY)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: drawRect.minX, y: 0,
                                         width: drawRect.width, height: drawRect.height))
        context.restoreGState()
    }

    /// Draws the date pill at the bottom-left of `rect`.
    private static func drawDateStamp(
        date: Date, formatter: DateFormatter, in rect: CGRect, config: Config
    ) {
        drawPill(
            text: formatter.string(from: date),
            alignment: .left,
            in: rect,
            config: config
        )
    }

    /// Draws the location pill at the bottom-right of `rect`.
    /// Does nothing when `locationName` is nil (photo has no GPS data).
    private static func drawLocationStamp(
        locationName: String?, in rect: CGRect, config: Config
    ) {
        guard let name = locationName, !name.isEmpty else { return }
        drawPill(text: name, alignment: .right, in: rect, config: config)
    }

    private enum PillAlignment { case left, right }

    /// Shared pill renderer used by both date and location stamps.
    private static func drawPill(
        text: String,
        alignment: PillAlignment,
        in rect: CGRect,
        config: Config
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: config.dateFont,
            .foregroundColor: config.dateColor
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding  = config.datePadding
        let inset    = config.datePillInset

        let pillX: CGFloat
        switch alignment {
        case .left:  pillX = rect.minX + padding
        case .right: pillX = rect.maxX - padding - textSize.width - inset * 2
        }

        let pillRect = CGRect(
            x: pillX,
            y: rect.maxY - padding - textSize.height - inset * 2,
            width:  textSize.width  + inset * 2,
            height: textSize.height + inset * 2
        )

        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: config.dateCornerRadius)
        config.dateBackgroundColor.setFill()
        pillPath.fill()

        (text as NSString).draw(
            at: CGPoint(x: pillRect.minX + inset, y: pillRect.minY + inset),
            withAttributes: attributes
        )
    }
}
