import Foundation

// Locked Android IDs + official name metadata; complete provenance in Resources/TIEBA_EMOTICONS_PROVENANCE.md.
struct TiebaEmoticon: Equatable, Sendable {
    let resourceID: String
    let name: String
}

enum TiebaEmoticonRegistry {
    // Android defaults: 1...50, 61...101, 125...137. Official registered extensions: 102...124.
    private static let resourceNames: [Int: String] = [
        1: "呵呵",
        2: "哈哈",
        3: "吐舌",
        4: "啊",
        5: "酷",
        6: "怒",
        7: "开心",
        8: "汗",
        9: "泪",
        10: "黑线",
        11: "鄙视",
        12: "不高兴",
        13: "真棒",
        14: "钱",
        15: "疑问",
        16: "阴险",
        17: "吐",
        18: "咦",
        19: "委屈",
        20: "花心",
        21: "呼~",
        22: "笑眼",
        23: "冷",
        24: "太开心",
        25: "滑稽",
        26: "勉强",
        27: "狂汗",
        28: "乖",
        29: "睡觉",
        30: "惊哭",
        31: "哼",
        32: "惊讶",
        33: "喷",
        34: "爱心",
        35: "心碎",
        36: "玫瑰",
        37: "礼物",
        38: "彩虹",
        39: "星星月亮",
        40: "太阳",
        41: "钱币",
        42: "灯泡",
        43: "茶杯",
        44: "蛋糕",
        45: "音乐",
        46: "haha",
        47: "胜利",
        48: "大拇指",
        49: "弱",
        50: "OK",
        61: "生气",
        62: "吃瓜",
        63: "扔便便",
        64: "惊恐",
        65: "哎呦",
        66: "小乖",
        67: "捂嘴笑",
        68: "你懂的",
        69: "what",
        70: "酸爽",
        71: "呀咩爹",
        72: "笑尿",
        73: "挖鼻",
        74: "犀利",
        75: "小红脸",
        76: "懒得理",
        77: "沙发",
        78: "手纸",
        79: "香蕉",
        80: "便便",
        81: "药丸",
        82: "红领巾",
        83: "蜡烛",
        84: "三道杠",
        85: "暗中观察",
        86: "吃瓜",
        87: "喝酒",
        88: "嘿嘿嘿",
        89: "噗",
        90: "困成狗",
        91: "微微一笑",
        92: "托腮",
        93: "摊手",
        94: "柯基暗中观察",
        95: "欢呼",
        96: "炸药",
        97: "突然兴奋",
        98: "紧张",
        99: "黑头瞪眼",
        100: "黑头高兴",
        101: "不跟丑人说话",
        102: "么么哒",
        103: "亲亲才能起来",
        104: "伦家只是宝宝",
        105: "你是我的人",
        106: "假装看不见",
        107: "单身等撩",
        108: "吓到宝宝了",
        109: "哈哈哈",
        110: "嗯嗯",
        111: "好幸福",
        112: "宝宝不开心",
        113: "小姐姐别走",
        114: "小姐姐在吗",
        115: "小姐姐来啦",
        116: "小姐姐来玩呀",
        117: "我养你",
        118: "我是不会骗你的",
        119: "扎心了",
        120: "无聊",
        121: "月亮代表我的心",
        122: "来追我呀",
        123: "爱你的形状",
        124: "白眼",
        125: "奥特曼",
        126: "不听",
        127: "干饭",
        128: "望远镜",
        129: "菜狗",
        130: "老虎",
        131: "嗷呜",
        132: "烟花",
        133: "香槟",
        134: "文字啊",
        135: "文字对",
        136: "鼠1",
        137: "鼠2"
    ]

    static let catalog: [TiebaEmoticon] = resourceNames.keys.sorted().compactMap { number in
        resourceNames[number].map { TiebaEmoticon(resourceID: "image_emoticon\(number)", name: $0) }
    }
    static let bundledResourceIDs = Set(catalog.map(\.resourceID))

    private static let canonicalNames: [String: TiebaEmoticon] = {
        var names: [String: TiebaEmoticon] = [:]
        // Duplicate 吃瓜 IDs62/86: plain text follows the official editor's current ID86.
        // Explicit content nodes always retain their supplied ID, including legacy ID62.
        for emoticon in catalog { names[emoticon.name] = emoticon }
        names["小姐姐来拉"] = names["小姐姐来啦"]
        return names
    }()

    static func named(_ name: String, webSyntax: Bool = false) -> TiebaEmoticon? {
        if webSyntax && name == "生气" {
            return TiebaEmoticon(resourceID: "image_emoticon31", name: name)
        }
        return canonicalNames[name]
    }

    static func resolve(registryKey: String, name: String) -> TiebaEmoticon? {
        let resourceID = registryKey == "image_emoticon" ? "image_emoticon1" : registryKey
        guard bundledResourceIDs.contains(resourceID) else { return nil }
        let knownName = catalog.first { $0.resourceID == resourceID }?.name ?? "贴吧"
        return TiebaEmoticon(resourceID: resourceID, name: name.isEmpty ? knownName : name)
    }
}
