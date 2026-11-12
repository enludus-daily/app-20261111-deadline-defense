import Foundation

/// 日本語と英語の対（手で用意した中身。String Catalog を通さず、ここで両方を持つ）
struct Bilingual: Equatable, Hashable, Sendable {
    let ja: String
    let en: String

    init(_ ja: String, _ en: String) {
        self.ja = ja
        self.en = en
    }

    func text(japanese: Bool) -> String { japanese ? ja : en }
}

/// 先延ばしに効く「今日の作戦」
struct Tactic: Equatable, Sendable {
    let title: Bilingual
    let detail: Bilingual
}

/// 大きい用事の「分け方の型」
struct SplitTemplate: Equatable, Identifiable, Sendable {
    let id: String
    let name: Bilingual
    /// 名前にこの言葉が入っていたら、この型を勧める
    let keywords: [String]
    let steps: [Bilingual]
    let isFree: Bool
}

enum Content {
    /// 撮影で日本語の画面を撮るとき（-screenshotScene <名前>_ja）に true。CI のシミュレータは英語のため
    nonisolated(unsafe) static var forcedJapanese = false

    static var isJapanese: Bool {
        forcedJapanese || (Bundle.main.preferredLocalizations.first ?? "ja").hasPrefix("ja")
    }

    /// 日付から、今日の作戦を 1 つ選ぶ（同じ日は同じ作戦）
    static func tactic(for day: Date, calendar: Calendar) -> Tactic {
        let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
        return tactics[ordinal % tactics.count]
    }

    /// 名前から、いちばん合う型を探す
    static func suggestedTemplate(for title: String, includePro: Bool) -> SplitTemplate? {
        let lower = title.lowercased()
        return templates
            .filter { includePro || $0.isFree }
            .first { template in template.keywords.contains { lower.contains($0.lowercased()) } }
    }

    static let fallbackSteps: [Bilingual] = [
        Bilingual("5分だけ手をつける", "Start for just 5 minutes"),
        Bilingual("半分まで進める", "Get it halfway"),
        Bilingual("仕上げて出す", "Finish and send it"),
    ]

    static let tactics: [Tactic] = [
        Tactic(title: Bilingual("5分だけ", "Just five minutes"), detail: Bilingual("「5分だけやる」と決めて始める。始めると続きやすい。", "Promise yourself five minutes. Starting is the hard part.")),
        Tactic(title: Bilingual("いちばん小さい一歩", "The tiniest step"), detail: Bilingual("ファイルを開くだけ、宛先を書くだけ。それも1体として倒していい。", "Just open the file, just type the address. That counts as a foe too.")),
        Tactic(title: Bilingual("2分ルール", "The two-minute rule"), detail: Bilingual("2分で終わるものは、追加せずにその場で済ませる。", "If it takes under two minutes, do it now instead of adding it.")),
        Tactic(title: Bilingual("朝の1体", "One before noon"), detail: Bilingual("いちばん重い敵を、昼までに1体だけ倒す。", "Take down your heaviest foe before lunch.")),
        Tactic(title: Bilingual("分けて倒す", "Split and conquer"), detail: Bilingual("大きい敵は長押しで分ける。小さい敵は1回で倒れる。", "Long-press a big foe to split it. Small foes fall in one shot.")),
        Tactic(title: Bilingual("場所を変える", "Change the scene"), detail: Bilingual("机が重いなら、カフェや別の部屋で最初の一歩だけ。", "If your desk feels heavy, take the first step somewhere else.")),
        Tactic(title: Bilingual("通知を切る", "Silence the noise"), detail: Bilingual("25分だけ通知を切って、1体に集中する。", "Mute notifications for 25 minutes and focus on one foe.")),
        Tactic(title: Bilingual("終わりの形を決める", "Define done"), detail: Bilingual("「どうなったら済んだか」を1行で書くと、手が動く。", "Write one line about what done looks like. Your hands will follow.")),
        Tactic(title: Bilingual("下書きは下手でいい", "Ugly first drafts"), detail: Bilingual("最初の版は、あとで直す前提で雑に出す。", "Make the first version rough on purpose. You will fix it later.")),
        Tactic(title: Bilingual("締め切りを前に", "Pull the deadline in"), detail: Bilingual("本当の締め切りの1日前を、自分の締め切りにする。", "Set your own deadline one day before the real one.")),
        Tactic(title: Bilingual("ご褒美を先に決める", "Name the reward"), detail: Bilingual("倒したら何をするか、先に決めておく。", "Decide what you will enjoy right after this foe falls.")),
        Tactic(title: Bilingual("だれかに言う", "Tell someone"), detail: Bilingual("「今日の夜までに出す」と1人に伝える。", "Tell one person you will finish it by tonight.")),
        Tactic(title: Bilingual("同じ時間に", "Same time, every day"), detail: Bilingual("毎日同じ時間を、敵を倒す時間にする。", "Make the same hour each day your defense hour.")),
        Tactic(title: Bilingual("いやな所から", "Worst part first"), detail: Bilingual("いちばんいやな部分を最初に済ませると、残りは軽い。", "Do the part you dread first. The rest gets lighter.")),
        Tactic(title: Bilingual("迷ったら近い敵", "When in doubt, closest first"), detail: Bilingual("何からやるか迷ったら、城にいちばん近い敵から。", "Not sure where to start? Take the foe closest to the castle.")),
        Tactic(title: Bilingual("完璧より提出", "Done beats perfect"), detail: Bilingual("8割で出して、直す時間をあとに取る。", "Ship it at 80 percent and leave time to polish later.")),
        Tactic(title: Bilingual("道具をそろえる", "Set up the tools"), detail: Bilingual("前の晩に、使う物を机に出しておく。", "Lay out what you need the night before.")),
        Tactic(title: Bilingual("タイマーを使う", "Use a timer"), detail: Bilingual("15分のタイマーを鳴らして、その間だけ向き合う。", "Set a 15-minute timer and face it only until it rings.")),
        Tactic(title: Bilingual("やらないことを決める", "Choose what to drop"), detail: Bilingual("今日は倒さない敵を、明日の波に回していい。", "It is fine to send some foes to tomorrow's wave.")),
        Tactic(title: Bilingual("体を先に動かす", "Move first"), detail: Bilingual("立って水を飲んでから座ると、始めやすい。", "Stand up, drink some water, then sit down and start.")),
        Tactic(title: Bilingual("音を味方に", "Let sound help"), detail: Bilingual("いつも同じ音楽をかけて、始める合図にする。", "Play the same music each time as your start signal.")),
        Tactic(title: Bilingual("返事は短く", "Short replies"), detail: Bilingual("メールの返事は3行でいい。長くしようとすると止まる。", "Three lines is enough for a reply. Aiming long makes you stall.")),
        Tactic(title: Bilingual("見える所に", "Keep it in sight"), detail: Bilingual("必要な書類を、目に入る場所に置く。", "Put the papers you need where you will see them.")),
        Tactic(title: Bilingual("途中で止める", "Stop mid-sentence"), detail: Bilingual("区切りの悪い所で止めると、次に始めやすい。", "Stop in the middle of something. Restarting is easier.")),
        Tactic(title: Bilingual("まとめて倒す", "Batch the small ones"), detail: Bilingual("軽い敵は3体まとめて、10分で片づける。", "Clear three light foes together in ten minutes.")),
        Tactic(title: Bilingual("責めない", "No blame"), detail: Bilingual("城に届いても大丈夫。明日の波で取り返せる。", "A foe reached the castle? It is okay. Tomorrow's wave is a new chance.")),
        Tactic(title: Bilingual("質問を先に", "Ask early"), detail: Bilingual("分からない所は、始める前にだれかに聞く。", "Ask your question before you start, not after you stall.")),
        Tactic(title: Bilingual("1つだけ開く", "One tab only"), detail: Bilingual("画面に開くのは、その敵に使う物だけ。", "Keep only what this foe needs open on your screen.")),
        Tactic(title: Bilingual("気分の波に乗る", "Ride your energy"), detail: Bilingual("元気な時間に重い敵、疲れた時間に軽い敵。", "Heavy foes when you are fresh, light ones when you are tired.")),
        Tactic(title: Bilingual("次の一歩を書く", "Write the next step"), detail: Bilingual("やめる前に、次にやることを1行残す。", "Before you stop, leave a note about the very next step.")),
        Tactic(title: Bilingual("比べない", "Do not compare"), detail: Bilingual("昨日の自分より1体多ければ十分。", "One more foe than yesterday is plenty.")),
        Tactic(title: Bilingual("先に予定に入れる", "Book the time"), detail: Bilingual("やる時間をカレンダーに入れて、約束にする。", "Put the work time on your calendar like a meeting.")),
        Tactic(title: Bilingual("型を使う", "Use a template"), detail: Bilingual("前にうまくいった分け方を、そのまま使う。", "Reuse a split that worked for you last time.")),
        Tactic(title: Bilingual("手を止めない", "Keep your hands moving"), detail: Bilingual("考えすぎたら、とりあえず箇条書きで手を動かす。", "Overthinking? Start a bullet list and keep typing.")),
        Tactic(title: Bilingual("ゴールの絵", "Picture the finish"), detail: Bilingual("倒したあとの、すっきりした夜を思い浮かべる。", "Imagine the calm evening after this foe falls.")),
        Tactic(title: Bilingual("仲間と同時に", "Work side by side"), detail: Bilingual("友だちと同じ時間に、それぞれの敵を倒す。", "Pick a time with a friend and each fight your own foes.")),
        Tactic(title: Bilingual("夜は軽く", "Light at night"), detail: Bilingual("寝る前は軽い敵だけ。重い敵は朝に回す。", "Only light foes before bed. Save heavy ones for morning.")),
        Tactic(title: Bilingual("理由を思い出す", "Remember why"), detail: Bilingual("その用事が済むと、だれが助かるかを考える。", "Think about who benefits once this is done.")),
        Tactic(title: Bilingual("砲台を信じる", "Trust your towers"), detail: Bilingual("1体倒すたびに城は強くなる。今日も1体から。", "Every foe you defeat makes the castle stronger. Start with one.")),
        Tactic(title: Bilingual("週のはじめに見渡す", "Scan the week"), detail: Bilingual("月曜に道の入口を見て、重い敵を先に分けておく。", "On Monday, look at the far end of the road and split the heavy ones early.")),
        Tactic(title: Bilingual("おわりの合図", "A closing ritual"), detail: Bilingual("1日の終わりに戦果を見て、今日を閉じる。", "End your day by checking the battle report.")),
        Tactic(title: Bilingual("休むのも作戦", "Rest is a tactic"), detail: Bilingual("疲れた日は、1体だけ倒して休む。", "On tired days, defeat just one foe and rest.")),
    ]

    static let templates: [SplitTemplate] = [
        SplitTemplate(id: "report", name: Bilingual("レポート・資料", "Report or paper"), keywords: ["レポート", "資料", "報告", "論文", "report", "paper", "essay", "doc"],
                      steps: [Bilingual("見出しだけ書く", "Write the headings only"), Bilingual("中身を雑に埋める", "Fill it in roughly"), Bilingual("読み直して出す", "Reread and submit")], isFree: true),
        SplitTemplate(id: "mail", name: Bilingual("返信・メール", "Reply or email"), keywords: ["返信", "メール", "連絡", "返事", "mail", "reply", "email", "message"],
                      steps: [Bilingual("言いたいことを1行", "Write the point in one line"), Bilingual("3行にして送る", "Expand to three lines and send")], isFree: true),
        SplitTemplate(id: "pay", name: Bilingual("支払い・手続き", "Payment or paperwork"), keywords: ["支払", "振込", "払う", "手続", "申請", "pay", "bill", "invoice", "form"],
                      steps: [Bilingual("必要な物を集める", "Gather what you need"), Bilingual("入力する", "Fill it in"), Bilingual("確認して完了", "Confirm and finish")], isFree: true),
        SplitTemplate(id: "slides", name: Bilingual("発表・スライド", "Slides or talk"), keywords: ["発表", "スライド", "プレゼン", "slides", "presentation", "talk", "deck"],
                      steps: [Bilingual("話す順番を5行", "Outline the talk in five lines"), Bilingual("スライドを作る", "Make the slides"), Bilingual("1回声に出して通す", "Rehearse once out loud")], isFree: true),
        SplitTemplate(id: "clean", name: Bilingual("片づけ・掃除", "Cleaning"), keywords: ["片づけ", "片付け", "掃除", "整理", "clean", "tidy", "declutter"],
                      steps: [Bilingual("床の物を戻す", "Put away what is on the floor"), Bilingual("拭く・掃く", "Wipe and sweep"), Bilingual("ゴミを出す", "Take out the trash")], isFree: true),
        SplitTemplate(id: "study", name: Bilingual("試験・勉強", "Exam or study"), keywords: ["試験", "テスト", "勉強", "課題", "宿題", "exam", "test", "study", "homework", "assignment"],
                      steps: [Bilingual("範囲を書き出す", "List what is covered"), Bilingual("前半をやる", "Do the first half"), Bilingual("後半をやる", "Do the second half")], isFree: true),
        SplitTemplate(id: "apply", name: Bilingual("申し込み・応募", "Application"), keywords: ["申し込", "申込", "応募", "エントリー", "apply", "application", "entry", "register"],
                      steps: [Bilingual("条件を読む", "Read the requirements"), Bilingual("書く欄を埋める", "Fill in the fields"), Bilingual("見直して送る", "Review and send")], isFree: true),
        SplitTemplate(id: "shop", name: Bilingual("買い物・準備", "Shopping or prep"), keywords: ["買い物", "買う", "準備", "用意", "shop", "buy", "prepare", "pack"],
                      steps: [Bilingual("要る物を書き出す", "List what you need"), Bilingual("そろえる", "Get everything together")], isFree: true),
        SplitTemplate(id: "taxes", name: Bilingual("確定申告・税", "Taxes"), keywords: ["確定申告", "税", "年末調整", "tax"],
                      steps: [Bilingual("領収書を集める", "Collect the receipts"), Bilingual("金額を入れる", "Enter the numbers"), Bilingual("送信する", "Submit it")], isFree: false),
        SplitTemplate(id: "move", name: Bilingual("引っ越し", "Moving"), keywords: ["引っ越", "転居", "move", "moving"],
                      steps: [Bilingual("段ボールを用意", "Get boxes"), Bilingual("1部屋ぶん詰める", "Pack one room"), Bilingual("住所の変更", "Change your address")], isFree: false),
        SplitTemplate(id: "trip", name: Bilingual("旅行の予約", "Trip booking"), keywords: ["旅行", "予約", "ホテル", "trip", "travel", "book", "hotel", "flight"],
                      steps: [Bilingual("日にちを決める", "Pick the dates"), Bilingual("候補を3つ比べる", "Compare three options"), Bilingual("予約する", "Book it")], isFree: false),
        SplitTemplate(id: "gift", name: Bilingual("贈り物", "Gift"), keywords: ["プレゼント", "贈り物", "お祝い", "gift", "present", "birthday"],
                      steps: [Bilingual("相手の好きな物を3つ", "Note three things they like"), Bilingual("選んで注文", "Choose and order"), Bilingual("カードを書く", "Write a card")], isFree: false),
        SplitTemplate(id: "resume", name: Bilingual("履歴書・職務経歴書", "Resume"), keywords: ["履歴書", "職務経歴", "resume", "cv"],
                      steps: [Bilingual("経歴を箇条書き", "Bullet your experience"), Bilingual("1枚に整える", "Fit it on one page"), Bilingual("だれかに見てもらう", "Get someone to review it")], isFree: false),
        SplitTemplate(id: "meeting", name: Bilingual("会議の準備", "Meeting prep"), keywords: ["会議", "打ち合わせ", "ミーティング", "meeting", "agenda"],
                      steps: [Bilingual("決めたいことを1行", "One line on what to decide"), Bilingual("資料を1枚", "One page of material"), Bilingual("参加者に送る", "Send it to attendees")], isFree: false),
        SplitTemplate(id: "blog", name: Bilingual("記事・投稿", "Post or article"), keywords: ["記事", "ブログ", "投稿", "note", "blog", "post", "article", "newsletter"],
                      steps: [Bilingual("言いたいことを3つ", "Three key points"), Bilingual("下書き", "Draft"), Bilingual("画像を付けて公開", "Add images and publish")], isFree: false),
        SplitTemplate(id: "code", name: Bilingual("プログラム・修正", "Code change"), keywords: ["実装", "修正", "バグ", "コード", "code", "bug", "fix", "implement", "feature"],
                      steps: [Bilingual("直す所を探す", "Find where to change"), Bilingual("書く", "Write it"), Bilingual("試して出す", "Test and ship")], isFree: false),
        SplitTemplate(id: "review", name: Bilingual("確認・レビュー", "Review"), keywords: ["確認", "レビュー", "チェック", "見直", "review", "check", "proofread"],
                      steps: [Bilingual("ざっと全体を見る", "Skim the whole thing"), Bilingual("気になる所に印", "Mark what bothers you"), Bilingual("返す", "Send it back")], isFree: false),
        SplitTemplate(id: "call", name: Bilingual("電話・予約の連絡", "Phone call"), keywords: ["電話", "問い合わせ", "call", "phone", "contact"],
                      steps: [Bilingual("聞くことを書く", "Write what to ask"), Bilingual("電話する", "Make the call")], isFree: false),
        SplitTemplate(id: "laundry", name: Bilingual("洗濯", "Laundry"), keywords: ["洗濯", "laundry", "washing"],
                      steps: [Bilingual("回す", "Start the machine"), Bilingual("干す", "Hang it up"), Bilingual("たたむ", "Fold it")], isFree: false),
        SplitTemplate(id: "cook", name: Bilingual("作り置き・料理", "Cooking"), keywords: ["料理", "作り置き", "ごはん", "cook", "meal", "dinner"],
                      steps: [Bilingual("献立を決める", "Pick the menu"), Bilingual("下ごしらえ", "Prep the ingredients"), Bilingual("作る", "Cook")], isFree: false),
        SplitTemplate(id: "budget", name: Bilingual("家計・お金の整理", "Budget"), keywords: ["家計", "家計簿", "予算", "budget", "expenses", "finance"],
                      steps: [Bilingual("今月の出費を集める", "Collect this month's spending"), Bilingual("分類する", "Sort it"), Bilingual("来月の上限を決める", "Set next month's limit")], isFree: false),
        SplitTemplate(id: "photo", name: Bilingual("写真の整理", "Photo cleanup"), keywords: ["写真", "アルバム", "photo", "album", "pictures"],
                      steps: [Bilingual("いらない写真を消す", "Delete the extras"), Bilingual("アルバムに分ける", "Sort into albums")], isFree: false),
        SplitTemplate(id: "doctor", name: Bilingual("病院・健康診断", "Doctor visit"), keywords: ["病院", "歯医者", "健康診断", "検診", "doctor", "dentist", "checkup"],
                      steps: [Bilingual("予約を取る", "Book the appointment"), Bilingual("必要な物を用意", "Prepare what to bring")], isFree: false),
        SplitTemplate(id: "renew", name: Bilingual("更新・解約", "Renew or cancel"), keywords: ["更新", "解約", "契約", "renew", "cancel", "subscription", "contract"],
                      steps: [Bilingual("今の契約を調べる", "Check the current plan"), Bilingual("手続きする", "Do the paperwork")], isFree: false),
        SplitTemplate(id: "thanks", name: Bilingual("お礼・あいさつ", "Thank-you note"), keywords: ["お礼", "あいさつ", "挨拶", "年賀", "thank", "greeting", "card"],
                      steps: [Bilingual("送る相手を書き出す", "List who to send to"), Bilingual("1人ずつ書く", "Write them one by one")], isFree: false),
        SplitTemplate(id: "video", name: Bilingual("動画の編集", "Video edit"), keywords: ["動画", "編集", "video", "edit", "youtube"],
                      steps: [Bilingual("素材を並べる", "Lay out the clips"), Bilingual("切ってつなぐ", "Cut and join"), Bilingual("文字と音を入れて書き出す", "Add text and music, then export")], isFree: false),
        SplitTemplate(id: "read", name: Bilingual("本を読む", "Reading"), keywords: ["読む", "読書", "本", "read", "book", "chapter"],
                      steps: [Bilingual("目次を見る", "Look at the contents"), Bilingual("前半を読む", "Read the first half"), Bilingual("後半を読んでメモ", "Read the rest and take notes")], isFree: false),
        SplitTemplate(id: "event", name: Bilingual("会・イベントの幹事", "Organizing an event"), keywords: ["幹事", "飲み会", "イベント", "パーティ", "event", "party", "organize"],
                      steps: [Bilingual("日にちの候補を送る", "Send date options"), Bilingual("お店を決める", "Pick the place"), Bilingual("案内を送る", "Send the details")], isFree: false),
        SplitTemplate(id: "practice", name: Bilingual("練習・稽古", "Practice"), keywords: ["練習", "稽古", "レッスン", "practice", "lesson", "rehearsal"],
                      steps: [Bilingual("準備運動", "Warm up"), Bilingual("苦手な所を3回", "Three passes on the hard part"), Bilingual("通しで1回", "One full run")], isFree: false),
        SplitTemplate(id: "plan", name: Bilingual("企画・計画", "Plan or proposal"), keywords: ["企画", "計画", "提案", "plan", "proposal", "pitch"],
                      steps: [Bilingual("ねらいを1行", "One line on the goal"), Bilingual("案を3つ出す", "Come up with three ideas"), Bilingual("1つに絞って書く", "Pick one and write it up")], isFree: false),
    ]
}
