import Foundation

struct WatchActivity: Identifiable {
    let id: String
    let label: String
    static let catalog: [WatchActivity] = {
        let labels: [String: String] = [
            "love": "Loves you", "loveHello": "Loving hello", "like": "Likes you", "likeHello": "Friendly hello",
            "return": "Return", "start": "Welcome", "tongue": "Tongue", "yawn": "Yawn", "happy": "Happy",
            "hearts": "Hearts", "letter": "Letter", "flying": "Fly", "diving": "Dive", "ball": "Ball",
            "horn": "Horn", "flip": "Flip", "piano": "Piano", "toast": "Toast", "onigiri": "Onigiri",
            "rice": "Rice", "tableToast": "Toast at table", "tableOnigiri": "Onigiri at table",
            "tableRice": "Rice at table", "walk": "Walk", "shower": "Shower", "bath": "Bath",
            "sand": "Sand", "sandFast": "Sand, fast", "reading": "Read", "page": "Turn page",
            "tv": "Watch TV", "tvExcited": "Excited TV", "lolly": "Lollipop", "icecream": "Ice cream",
            "dropLolly": "Drop lollipop", "dropIcecream": "Drop ice cream", "history": "History",
            "maths": "Math", "english": "English", "studySleep": "Sleep while studying", "kite": "Fly kite",
            "kiteFast": "Fly kite, fast", "rc": "Remote car", "rcFast": "Remote car, fast",
            "computer": "Computer", "typing": "Type", "yoyo": "Yo-yo", "yoyoDog": "Walk the yo-yo",
            "blocks": "Blocks", "blocksFall": "Blocks fall", "brush": "Brush teeth", "brushFast": "Brush, fast",
            "sleep-front": "Sleep facing front", "sleep-side": "Sleep on side", "sleep-back": "Sleep on back",
            "wakeStudy": "Wake from study", "look": "Look", "madLook": "Upset look", "showerLook": "Shower look",
            "bathLook": "Bath look", "pop": "Pop", "bed": "Bed", "neutral": "Neutral", "mad": "Upset", "left": "Away"
        ]
        guard let library = AnimationLibrary.bundled else { return [] }
        return library.clips.keys.map { WatchActivity(id: $0, label: labels[$0] ?? $0) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }()
}
