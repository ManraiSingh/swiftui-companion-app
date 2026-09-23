//
//  ZiggyFeatures.swift
//  Ziggy
//
//  Things that are built but not yet let out.
//
//  A flag here means the work is finished enough to live on main and be built
//  every time, but not finished enough to be in front of people — which is a
//  different thing from unfinished, and worth keeping separate from it.
//

enum ZiggyFeatures {

    /// The two-person photobooth.
    ///
    /// Everything works except the part nobody has been able to try: the
    /// camera, the live view of the other person, and how the cutout holds up
    /// on a real face in real light. Those need two real devices. Flip this
    /// to `true` once they have been through it.
    ///
    /// When it does go out, `NSCameraUsageDescription` in Info.plist needs the
    /// booth added back to it — the string has to describe what the build in
    /// front of the reviewer actually does, and right now that is Instants.
    static let photobooth = false
}
