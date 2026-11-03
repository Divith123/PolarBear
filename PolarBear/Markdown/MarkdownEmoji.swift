//
//  MarkdownEmoji.swift
//  PolarBear
//

import Foundation

/// `:tada:`-style shortcodes, the common ones.
nonisolated enum MarkdownEmoji {
    static func character(for name: String) -> String? {
        table[name.lowercased()]
    }

    private static let table: [String: String] = [
        "smile": "😄", "smiley": "😃", "grin": "😁", "laughing": "😆", "joy": "😂", "rofl": "🤣", "blush": "😊",
        "wink": "😉", "heart_eyes": "😍", "sunglasses": "😎", "thinking": "🤔", "neutral_face": "😐", "sob": "😭",
        "cry": "😢", "angry": "😠", "scream": "😱", "sleeping": "😴", "innocent": "😇", "stuck_out_tongue": "😛",
        "slightly_smiling_face": "🙂", "upside_down_face": "🙃", "hugs": "🤗", "relieved": "😌", "sweat_smile": "😅",
        "+1": "👍", "thumbsup": "👍", "-1": "👎", "thumbsdown": "👎", "clap": "👏", "wave": "👋", "raised_hands": "🙌",
        "pray": "🙏", "muscle": "💪", "ok_hand": "👌", "point_right": "👉", "point_left": "👈", "point_up": "☝️",
        "eyes": "👀", "brain": "🧠", "handshake": "🤝", "fist": "✊", "v": "✌️",
        "heart": "❤️", "blue_heart": "💙", "green_heart": "💚", "yellow_heart": "💛", "purple_heart": "💜",
        "broken_heart": "💔", "sparkling_heart": "💖", "star": "⭐", "star2": "🌟", "sparkles": "✨", "fire": "🔥",
        "boom": "💥", "zap": "⚡", "tada": "🎉", "confetti_ball": "🎊", "balloon": "🎈", "gift": "🎁", "trophy": "🏆",
        "medal_sports": "🏅", "crown": "👑", "gem": "💎", "100": "💯", "rocket": "🚀", "airplane": "✈️", "car": "🚗",
        "bike": "🚲", "ship": "🚢", "train": "🚆", "bulb": "💡", "bell": "🔔", "key": "🔑", "lock": "🔒",
        "unlock": "🔓", "mag": "🔍", "link": "🔗", "paperclip": "📎", "pushpin": "📌", "memo": "📝", "pencil": "📝",
        "pencil2": "✏️", "book": "📖", "books": "📚", "bookmark": "🔖", "page_facing_up": "📄", "file_folder": "📁",
        "open_file_folder": "📂", "clipboard": "📋", "calendar": "📅", "chart_with_upwards_trend": "📈",
        "chart_with_downwards_trend": "📉", "bar_chart": "📊", "email": "📧", "envelope": "✉️", "phone": "☎️",
        "computer": "💻", "keyboard": "⌨️", "desktop_computer": "🖥️", "iphone": "📱", "camera": "📷",
        "tv": "📺", "battery": "🔋", "gear": "⚙️", "wrench": "🔧", "hammer": "🔨", "hammer_and_wrench": "🛠️",
        "package": "📦", "construction": "🚧", "warning": "⚠️", "no_entry": "⛔", "stop_sign": "🛑",
        "white_check_mark": "✅", "heavy_check_mark": "✔️", "ballot_box_with_check": "☑️", "x": "❌",
        "negative_squared_cross_mark": "❎", "question": "❓", "exclamation": "❗", "heavy_plus_sign": "➕",
        "heavy_minus_sign": "➖", "arrow_right": "➡️", "arrow_left": "⬅️", "arrow_up": "⬆️", "arrow_down": "⬇️",
        "arrows_counterclockwise": "🔄", "recycle": "♻️", "information_source": "ℹ️", "new": "🆕", "ok": "🆗",
        "sos": "🆘", "bear": "🐻", "polar_bear": "🐻‍❄️", "cat": "🐱", "dog": "🐶", "mouse": "🐭", "fox_face": "🦊",
        "panda_face": "🐼", "penguin": "🐧", "bird": "🐦", "turtle": "🐢", "snake": "🐍", "bug": "🐛", "bee": "🐝",
        "butterfly": "🦋", "whale": "🐳", "fish": "🐟", "octopus": "🐙", "unicorn": "🦄", "tree": "🌳",
        "evergreen_tree": "🌲", "palm_tree": "🌴", "cactus": "🌵", "herb": "🌿", "four_leaf_clover": "🍀",
        "rose": "🌹", "sunflower": "🌻", "snowflake": "❄️", "cloud": "☁️", "sunny": "☀️", "umbrella": "☔",
        "rainbow": "🌈", "ocean": "🌊", "earth_africa": "🌍", "earth_americas": "🌎", "earth_asia": "🌏",
        "moon": "🌙", "apple": "🍎", "green_apple": "🍏", "banana": "🍌", "cherries": "🍒", "pizza": "🍕",
        "hamburger": "🍔", "coffee": "☕", "tea": "🍵", "beer": "🍺", "wine_glass": "🍷", "cake": "🍰",
        "cookie": "🍪", "ice_cream": "🍨", "popcorn": "🍿", "hourglass": "⌛", "watch": "⌚", "alarm_clock": "⏰",
        "stopwatch": "⏱️", "mortar_board": "🎓", "microscope": "🔬", "telescope": "🔭", "test_tube": "🧪",
        "dna": "🧬", "abacus": "🧮", "triangular_ruler": "📐", "straight_ruler": "📏", "art": "🎨", "musical_note": "🎵",
        "guitar": "🎸", "microphone": "🎤", "headphones": "🎧", "video_game": "🎮", "dart": "🎯", "checkered_flag": "🏁",
        "triangular_flag_on_post": "🚩", "robot": "🤖", "ghost": "👻", "skull": "💀", "poop": "💩", "shipit": "🐿️",
        "copyright": "©️", "registered": "®️", "tm": "™️", "infinity": "♾️", "peace_symbol": "☮️", "yin_yang": "☯️",
    ]
}
