import StoreKit
import SwiftUI

/// 課金の画面：価値を感じた直後（今日の波を守りきった・鍵のある物を押した）にだけ出す
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let reason: PaywallReason
    @State private var previewTheme: MapTheme = .harbor
    @State private var buying = false
    @State private var message: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(headline)
                            .font(.system(size: 11, weight: .medium))
                            .kerning(0.6)
                            .foregroundStyle(Theme.peachDeep)
                        Text("城を、もっと自分の形に")
                            .font(Theme.serif(26, .regular))
                            .kerning(-0.6)
                            .foregroundStyle(Theme.ink)
                        Text("しめきりディフェンス Pro は、1回の買い切りです。サブスクではありません。")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // 地図のテーマを実物で見比べる（払う前に試せる）
                    VStack(alignment: .leading, spacing: 8) {
                        MiniMap(theme: previewTheme)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).stroke(Theme.line, lineWidth: 1))
                            .animation(.easeOut(duration: 0.25), value: previewTheme)
                        HStack(spacing: 6) {
                            ForEach(MapTheme.allCases.filter(\.isPro)) { theme in
                                ChipButton(title: theme.name, selected: previewTheme == theme) {
                                    model.select()
                                    previewTheme = theme
                                }
                            }
                        }
                    }

                    VStack(spacing: 0) {
                        Feature(systemName: "map", title: "地図のテーマ 3つ", detail: "港・雪原・夕暮れ。毎日見る道を、気分で変えられます。")
                        Feature(systemName: "sun.max", title: "朝の砲台・連射台", detail: "正午までに倒すと2倍。続けて倒すと連続が長く続きます。")
                        Feature(systemName: "scissors", title: "分け方の型 30", detail: "確定申告・引っ越し・履歴書・旅行の予約など。無料は8つ。")
                        Feature(systemName: "square.grid.3x3", title: "1年の戦いの記録", detail: "52週のマス、期限内に倒した割合、よく倒す時間。", last: true)
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.line, lineWidth: 1))

                    Text("用事・締め切り・敵・砲台・分ける・通知・今日の戦果は、ずっと無料です。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)

                    buyArea

                    HStack(spacing: 16) {
                        Button("購入を復元") {
                            Task {
                                await model.purchases.restore()
                                message = model.isPro ? LocalizedStringKey("Pro を復元しました") : LocalizedStringKey("復元できる購入が見つかりませんでした")
                            }
                        }
                        Link("プライバシーポリシー", destination: URL(string: "https://github.com/enludus-daily/app-20261111-deadline-defense/blob/main/PRIVACY.md")!)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.skyDeep)
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .accessibilityIdentifier("main.closePaywall")
                }
            }
        }
        .tint(Theme.skyDeep)
        .task {
            if model.purchases.loadState == .idle { await model.purchases.load() }
        }
        .onChange(of: model.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private var headline: LocalizedStringKey {
        switch reason {
        case .cleared: return "今日の波を守りきりました"
        case .theme: return "地図のテーマは Pro"
        case .tower: return "この砲台は Pro"
        case .template: return "この型は Pro"
        case .history: return "1年の記録は Pro"
        case .settings: return "Pro"
        }
    }

    @ViewBuilder
    private var buyArea: some View {
        VStack(spacing: 8) {
            switch model.purchases.loadState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 52)
            case .ready:
                if let product = model.purchases.products.first {
                    Button {
                        Task {
                            buying = true
                            let outcome = await model.purchases.purchase(product)
                            buying = false
                            switch outcome {
                            case .purchased: message = "ありがとうございます！ Pro が使えます"
                            case .pending: message = "購入の承認を待っています"
                            case .failed: message = "購入できませんでした。時間をおいてもう一度お試しください"
                            case .cancelled: message = nil
                            }
                        }
                    } label: {
                        HStack {
                            Text("Pro を買う")
                            Text("·")
                            Text(product.displayPrice)
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(Theme.skyDeep))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(buying)
                    .accessibilityIdentifier("main.buy")
                    Text("1回だけのお支払い。ファミリー共有に対応しています。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sub)
                }
            case .unavailable:
                VStack(spacing: 6) {
                    Text("いまは購入できません")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("App Store につながらないようです。電波のよい所で、もう一度開いてください。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("もう一度読み込む") { Task { await model.purchases.load() } }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.skyDeep)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.card))
            }
            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.skyDeep)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct Feature: View {
    let systemName: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemName)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.skyDeep)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.skySoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                    Text(detail).font(.system(size: 12)).foregroundStyle(Theme.sub).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            if !last { Divider().padding(.leading, 58) }
        }
    }
}
