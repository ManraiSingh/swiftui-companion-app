//
//  ScrapbookPDF.swift
//  Ziggy
//
//  Printing a book out.
//
//  Each page is rendered through the very same view the book shows, so what
//  comes out is what you made rather than a second drawing of it that could
//  drift away from the first.
//

import SwiftUI
import UIKit

enum ScrapbookPDF {

    /// A page, in points. The proportion is the scrapbook's own 0.74, not A4's
    /// — a page laid out to one shape and printed to another would either
    /// letterbox or crop, and cropping a scrapbook loses the corners where the
    /// tape and the dates live.
    static let pageSize = CGSize(width: 612, height: 612 / 0.74)

    /// Renders the whole book and writes it to a file, returning where it went.
    ///
    /// The elements come in as a dictionary rather than being fetched here, so
    /// this stays a pure "draw what you are given" step and the caller decides
    /// how much of the book to print.
    @MainActor
    static func write(
        book: ScrapbookBook,
        pages: [ScrapbookPage],
        elements: [String: [ScrapbookElement]],
        watermark: Bool = false
    ) -> URL? {

        guard !pages.isEmpty else { return nil }

        let bounds = CGRect(origin: .zero, size: pageSize)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: book.title,
            kCGPDFContextCreator as String: "Ziggy"
        ]

        let data = UIGraphicsPDFRenderer(bounds: bounds, format: format)
            .pdfData { context in

                for page in pages {

                    context.beginPage()

                    let leaf = ScrapbookPagePreview(
                        page: page,
                        elements: elements[page.id] ?? [],
                        forPrint: true
                    )
                    .frame(width: pageSize.width, height: pageSize.height)

                    let renderer = ImageRenderer(content: leaf)
                    renderer.proposedSize = ProposedViewSize(pageSize)

                    // `render` hands back a closure that draws into a CGContext,
                    // so shapes and type go into the PDF as shapes and type.
                    // Going via `uiImage` would flatten every page to a bitmap
                    // and the words would print soft.
                    //
                    // The flip is not optional. A PDF context counts upwards
                    // from the bottom-left and `UIGraphicsPDFRenderer` has
                    // already turned it the UIKit way up; the renderer's
                    // closure then draws top-down as well, and two flips is
                    // one too many — every page came out mirrored, with the
                    // writing back to front.
                    let cg = context.cgContext
                    cg.saveGState()
                    cg.translateBy(x: 0, y: pageSize.height)
                    cg.scaleBy(x: 1, y: -1)
                    renderer.render { _, draw in draw(cg) }
                    cg.restoreGState()

                    if watermark { stamp() }
                }
            }

        let name = filename(for: book)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// The line a free export carries.
    ///
    /// Small, at the very foot of the page, in the same grey the dates are set
    /// in. A free page is meant to be worth sending to somebody, because a page
    /// somebody sends on is an advert and a page they are too embarrassed to
    /// send is nothing at all — so this reads as a colophon, not a stamp across
    /// the middle of the work.
    private static func stamp() {

        let text = "Made in Ziggy"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: UIColor.black.withAlphaComponent(0.28),
            .kern: 1.2
        ]

        let size = (text as NSString).size(withAttributes: attributes)

        (text as NSString).draw(
            at: CGPoint(
                x: (pageSize.width - size.width) / 2,
                y: pageSize.height - size.height - 18
            ),
            withAttributes: attributes
        )
    }

    /// A filename that reads like the book, with anything a file system would
    /// object to taken out.
    private static func filename(for book: ScrapbookBook) -> String {

        let allowed = CharacterSet.alphanumerics.union(.whitespaces)

        let cleaned = book.title.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .joined(separator: "-")

        return (cleaned.isEmpty ? "Scrapbook" : cleaned) + ".pdf"
    }
}

/// A finished file, ready to present. A plain `URL` can't drive `sheet(item:)`
/// — it isn't `Identifiable`, and making it so everywhere to suit one screen
/// would be a heavy way to get an id.
struct ScrapbookExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Share sheet

/// The system share sheet, for handing the finished file on.
///
/// `ShareLink` would do this in one line, but it wants the file to exist before
/// the view is built — and the book is only rendered once you ask for it.
struct ScrapbookShareSheet: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
