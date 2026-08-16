//
//  ScrapbookManager.swift
//  Ziggy
//
//  Firestore sync for the shared scrapbook.
//
//  Deliberately a separate service rather than more surface on
//  FirestoreManager: nothing here touches the pet, the widget or any existing
//  document, so a mistake in the scrapbook can't take the rest of the app
//  down with it.
//
//  Shape:
//    relationships/{code}/scrapbooks/{book}
//                                   /pages/{page}
//                                         /elements/{element}
//
//  One document per element — not per page. A page holding ten photos would
//  blow through Firestore's 1 MB document ceiling if they shared a document,
//  and per-element writes mean two people can rearrange the same page at once
//  without overwriting each other.
//

// `@preconcurrency` because the Firebase SDK predates strict concurrency and
// doesn't mark `Firestore` as Sendable, even though it is documented as
// thread-safe. Without it, handing a database handle to a batch callback
// warns. It only silences Sendable complaints from Firebase — the actor
// isolation of everything in this file is still checked.
@preconcurrency import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import Combine

@MainActor
final class ScrapbookManager: ObservableObject {

    static let shared = ScrapbookManager()

    private let db = Firestore.firestore()

    @Published private(set) var books: [ScrapbookBook] = []
    @Published private(set) var pages: [ScrapbookPage] = []
    @Published private(set) var elements: [ScrapbookElement] = []
    @Published private(set) var ornaments: [ScrapbookOrnamentPlacement] = []

    /// Surfaced in the UI so a permissions failure doesn't just look like an
    /// empty shelf. See the note on Firestore rules in the README.
    @Published var lastError: String?

    private var shelfListener: ListenerRegistration?
    private var pagesListener: ListenerRegistration?
    private var elementsListener: ListenerRegistration?
    private var ornamentsListener: ListenerRegistration?

    private var openBookID: String?
    private var openPageID: String?

    private init() {}

    private var code: String { RelationshipManager.shared.relationshipCode }

    private var author: String {
        let name = UserManager.shared.username
        return name.isEmpty ? "Someone" : name
    }

    private func shelfRef() -> CollectionReference? {
        guard !code.isEmpty else { return nil }
        return db.collection("relationships").document(code).collection("scrapbooks")
    }

    /// One document holding the whole shelf arrangement. The ornaments are a
    /// single small array, so a document beats a collection here — moving the
    /// lamp shouldn't cost a read per object on the shelf.
    private func shelfMetaRef() -> DocumentReference? {
        guard !code.isEmpty else { return nil }
        return db.collection("relationships").document(code)
            .collection("scrapbookMeta").document("shelf")
    }

    private func pagesRef(_ bookID: String) -> CollectionReference? {
        shelfRef()?.document(bookID).collection("pages")
    }

    private func elementsRef(_ bookID: String, _ pageID: String) -> CollectionReference? {
        pagesRef(bookID)?.document(pageID).collection("elements")
    }

    // MARK: - Shelf

    func startShelf() {

        guard let ref = shelfRef() else { return }
        shelfListener?.remove()

        shelfListener = ref
            .addSnapshotListener { [weak self] snapshot, error in
              MainActor.assumeIsolated {

                guard let self else { return }

                if let error {
                    self.lastError = error.localizedDescription
                    return
                }

                self.lastError = nil
                self.books = (snapshot?.documents ?? []).map { document in
                    let data = document.data()
                    return ScrapbookBook(
                        id: document.documentID,
                        title: data["title"] as? String ?? "Untitled",
                        coverIndex: data["coverIndex"] as? Int ?? 0,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                        pageCount: data["pageCount"] as? Int ?? 0,
                        tilt: data["tilt"] as? Double ?? 0,
                        sizeScale: data["sizeScale"] as? Double ?? 1,
                        position: data["position"] as? Double
                            ?? (data["createdAt"] as? Timestamp)?.dateValue()
                                .timeIntervalSince1970
                            ?? 0
                    )
                }
                .sorted { $0.position < $1.position }
              }
            }
    }

    func stopShelf() {
        shelfListener?.remove()
        shelfListener = nil
    }

    /// Creates the book *and* its first page, so opening a brand new book
    /// never lands on nothing.
    func createBook(title: String, coverIndex: Int, completion: ((String?) -> Void)? = nil) {

        guard let ref = shelfRef() else { completion?(nil); return }

        let bookID = UUID().uuidString
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)

        ref.document(bookID).setData([
            "title": clean.isEmpty ? "Untitled" : clean,
            "coverIndex": coverIndex,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "pageCount": 1,
            "createdBy": author,
            "position": Date().timeIntervalSince1970
        ]) { [weak self] error in
          MainActor.assumeIsolated {

            guard let self else { return }

            if let error {
                self.lastError = error.localizedDescription
                completion?(nil)
                return
            }

            let page = ScrapbookPage.blank(index: 0)
            self.pagesRef(bookID)?.document(page.id).setData([
                "index": 0,
                "paperIndex": 0,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])

            completion?(bookID)
          }
        }
    }

    func renameBook(_ bookID: String, to title: String) {

        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        shelfRef()?.document(bookID).updateData([
            "title": clean,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// How the book is arranged on the shelf. Deliberately separate from
    /// `updatedAt`: nudging a spine straight is not the same as adding a
    /// memory, and it shouldn't jump the book to the front of the shelf.
    func setLayout(_ bookID: String, tilt: Double, sizeScale: Double) {
        shelfRef()?.document(bookID).updateData([
            "tilt": tilt,
            "sizeScale": sizeScale
        ])
    }

    func setCover(_ bookID: String, coverIndex: Int) {
        shelfRef()?.document(bookID).updateData([
            "coverIndex": coverIndex,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Puts a book at a given point in the running order.
    ///
    /// Positions are fractional, so dropping something between two neighbours
    /// is one write to one document — no renumbering of the shelf, and two
    /// people rearranging at once can't collide over a shared sequence.
    func setBookPosition(_ bookID: String, to position: Double) {

        shelfRef()?.document(bookID).updateData(["position": position])

        // Applied locally as well: a drag reorders faster than Firestore
        // answers, and without this every step after the first would be
        // computed from a stale order.
        if let index = books.firstIndex(where: { $0.id == bookID }) {
            books[index].position = position
            books.sort { $0.position < $1.position }
        }
    }

    // MARK: - Ornaments

    func startOrnaments() {

        guard let ref = shelfMetaRef() else { return }
        ornamentsListener?.remove()

        ornamentsListener = ref.addSnapshotListener { [weak self] snapshot, error in
          MainActor.assumeIsolated {

            guard let self else { return }

            if let error {
                self.lastError = error.localizedDescription
                return
            }

            let raw = snapshot?.data()?["ornaments"] as? [[String: Any]] ?? []

            self.ornaments = raw.compactMap { entry in
                guard let id = entry["id"] as? String,
                      let kind = entry["kind"] as? Int else { return nil }
                return ScrapbookOrnamentPlacement(
                    id: id,
                    position: entry["position"] as? Double ?? 4_000_000_000,
                    kind: kind,
                    scale: entry["scale"] as? Double ?? 1
                )
            }
            .sorted { $0.position < $1.position }
          }
        }
    }

    func stopOrnaments() {
        ornamentsListener?.remove()
        ornamentsListener = nil
    }

    /// What's actually drawn: whatever the couple arranged, or the stock
    /// arrangement until one of them moves something.
    var resolvedOrnaments: [ScrapbookOrnamentPlacement] {
        ornaments.isEmpty
            ? ScrapbookOrnamentPlacement.defaults(spanning: books.map(\.position))
            : ornaments
    }

    /// Writes the whole arrangement back. It's one small array, so replacing
    /// it wholesale avoids the ordering problems of patching a single entry.
    func saveOrnaments(_ placements: [ScrapbookOrnamentPlacement]) {

        ornaments = placements

        shelfMetaRef()?.setData([
            "ornaments": placements.map {
                ["id": $0.id, "position": $0.position,
                 "kind": $0.kind, "scale": $0.scale]
            }
        ], merge: true)
    }

    /// Removes the book and everything under it.
    ///
    /// Firestore does not cascade, so the pages and elements are walked by
    /// hand. Done client-side because a Cloud Function for this would need a
    /// deploy the rest of the feature doesn't.
    func deleteBook(_ bookID: String) {

        // Every reference is resolved up front so the nested callbacks don't
        // have to reach back into main-actor state to do their work.
        guard let pages = pagesRef(bookID), let shelf = shelfRef() else { return }
        let database = db

        pages.getDocuments { snapshot, _ in

            let group = DispatchGroup()

            for page in snapshot?.documents ?? [] {
                group.enter()
                page.reference.collection("elements").getDocuments { elementSnapshot, _ in
                    let batch = database.batch()
                    for element in elementSnapshot?.documents ?? [] {
                        batch.deleteDocument(element.reference)
                    }
                    batch.deleteDocument(page.reference)
                    batch.commit { _ in group.leave() }
                }
            }

            group.notify(queue: .main) {
                shelf.document(bookID).delete()
            }
        }
    }

    // MARK: - Pages

    func startPages(bookID: String) {

        guard let ref = pagesRef(bookID) else { return }

        openBookID = bookID
        pagesListener?.remove()
        pages = []

        pagesListener = ref
            .order(by: "index")
            .addSnapshotListener { [weak self] snapshot, error in
              MainActor.assumeIsolated {

                guard let self else { return }

                if let error {
                    self.lastError = error.localizedDescription
                    return
                }

                self.pages = (snapshot?.documents ?? []).enumerated().map { offset, document in
                    let data = document.data()
                    return ScrapbookPage(
                        id: document.documentID,
                        index: data["index"] as? Int ?? offset,
                        paperIndex: data["paperIndex"] as? Int ?? 0,
                        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
              }
            }
    }

    func stopPages() {
        pagesListener?.remove()
        pagesListener = nil
        openBookID = nil
        pages = []
    }

    func addPage(bookID: String, completion: ((String?) -> Void)? = nil) {

        guard let ref = pagesRef(bookID) else { completion?(nil); return }

        let nextIndex = (pages.map(\.index).max() ?? -1) + 1
        let page = ScrapbookPage.blank(index: nextIndex)

        ref.document(page.id).setData([
            "index": nextIndex,
            "paperIndex": pages.last?.paperIndex ?? 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
          MainActor.assumeIsolated {

            if let error {
                self?.lastError = error.localizedDescription
                completion?(nil)
                return
            }

            self?.shelfRef()?.document(bookID).updateData([
                "pageCount": nextIndex + 1,
                "updatedAt": FieldValue.serverTimestamp()
            ])

            completion?(page.id)
          }
        }
    }

    func setPaper(bookID: String, pageID: String, paperIndex: Int) {
        pagesRef(bookID)?.document(pageID).updateData([
            "paperIndex": paperIndex,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func deletePage(bookID: String, pageID: String) {

        guard let elements = elementsRef(bookID, pageID),
              let pages = pagesRef(bookID) else { return }
        let database = db

        elements.getDocuments { snapshot, _ in
            let batch = database.batch()
            for document in snapshot?.documents ?? [] {
                batch.deleteDocument(document.reference)
            }
            batch.commit { _ in
                pages.document(pageID).delete()
            }
        }
    }

    // MARK: - Elements

    func startElements(bookID: String, pageID: String) {

        guard let ref = elementsRef(bookID, pageID) else { return }

        openPageID = pageID
        elementsListener?.remove()
        elements = []

        elementsListener = ref
            .order(by: "z")
            .addSnapshotListener { [weak self] snapshot, error in
              MainActor.assumeIsolated {

                guard let self else { return }

                if let error {
                    self.lastError = error.localizedDescription
                    return
                }

                self.elements = (snapshot?.documents ?? []).compactMap { document in

                    let data = document.data()
                    guard let raw = data["kind"] as? String,
                          let kind = ScrapbookElementKind(rawValue: raw) else { return nil }

                    return ScrapbookElement(
                        id: document.documentID,
                        kind: kind,
                        x: data["x"] as? Double ?? 0.5,
                        y: data["y"] as? Double ?? 0.5,
                        scale: data["scale"] as? Double ?? 1,
                        rotation: data["rotation"] as? Double ?? 0,
                        z: data["z"] as? Int ?? 0,
                        payload: data["payload"] as? String ?? "",
                        colorHex: data["colorHex"] as? String ?? "#2E2A27",
                        frameIndex: data["frameIndex"] as? Int ?? 0,
                        fontIndex: data["fontIndex"] as? Int ?? 0,
                        widthValue: data["widthValue"] as? Double ?? 6,
                        createdBy: data["createdBy"] as? String ?? "",
                        aspect: data["aspect"] as? Double ?? 1,
                        locked: data["locked"] as? Bool ?? false,
                        brushIndex: data["brushIndex"] as? Int ?? 0
                    )
                }
              }
            }
    }

    func stopElements() {
        elementsListener?.remove()
        elementsListener = nil
        openPageID = nil
        elements = []
    }

    /// Highest z on the page plus one — new things land on top.
    var nextZ: Int { (elements.map(\.z).max() ?? 0) + 1 }

    func add(_ element: ScrapbookElement, bookID: String, pageID: String) {

        guard let ref = elementsRef(bookID, pageID) else { return }

        var payload = payloadDictionary(element)
        payload["createdAt"] = FieldValue.serverTimestamp()

        ref.document(element.id).setData(payload) { [weak self] error in
            MainActor.assumeIsolated {
                if let error { self?.lastError = error.localizedDescription }
            }
        }

        touch(bookID: bookID, pageID: pageID)
    }

    /// Position-only update, used while dragging. Kept separate from `add` so
    /// a nudge doesn't rewrite a 400 KB photo payload every time.
    func move(_ element: ScrapbookElement, bookID: String, pageID: String) {

        elementsRef(bookID, pageID)?.document(element.id).updateData([
            "x": element.x,
            "y": element.y,
            "scale": element.scale,
            "rotation": element.rotation,
            "z": element.z
        ])

        touch(bookID: bookID, pageID: pageID)
    }

    func update(_ element: ScrapbookElement, bookID: String, pageID: String) {
        elementsRef(bookID, pageID)?.document(element.id).updateData(payloadDictionary(element))
        touch(bookID: bookID, pageID: pageID)
    }

    func delete(_ elementID: String, bookID: String, pageID: String) {
        elementsRef(bookID, pageID)?.document(elementID).delete()
        touch(bookID: bookID, pageID: pageID)
    }

    private func payloadDictionary(_ element: ScrapbookElement) -> [String: Any] {
        [
            "kind": element.kind.rawValue,
            "x": element.x,
            "y": element.y,
            "scale": element.scale,
            "rotation": element.rotation,
            "z": element.z,
            "payload": element.payload,
            "colorHex": element.colorHex,
            "frameIndex": element.frameIndex,
            "fontIndex": element.fontIndex,
            "widthValue": element.widthValue,
            "createdBy": element.createdBy.isEmpty ? author : element.createdBy,
            "aspect": element.aspect,
            "locked": element.locked,
            "brushIndex": element.brushIndex
        ]
    }

    /// Bumps the book so the shelf reorders and the partner sees it move.
    private func touch(bookID: String, pageID: String) {
        pagesRef(bookID)?.document(pageID).updateData([
            "updatedAt": FieldValue.serverTimestamp()
        ])
        shelfRef()?.document(bookID).updateData([
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Teardown

    /// Mirrors `FirestoreManager.handleDisconnect()` — when the pairing goes
    /// away every listener has to go with it, or the next relationship
    /// inherits the last one's shelf.
    func handleDisconnect() {
        stopElements()
        stopPages()
        stopOrnaments()
        stopShelf()
        books = []
        ornaments = []
        lastError = nil
    }
}
