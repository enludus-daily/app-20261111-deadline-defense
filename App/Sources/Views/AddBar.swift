import SwiftUI

/// 1 行＋締め切りのチップで 3 秒の追加。重さは小さなチップで選ぶ（既定は「ふつう」）
struct AddBar: View {
    @Environment(AppModel.self) private var model
    @State private var title = ""
    @State private var chip: DeadlineChip? = .tonight
    @State private var customDate = Date().addingTimeInterval(3 * 86_400)
    @State private var useCustom = false
    @State private var weight = 2
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.sub)
                TextField("締め切りのある用事を1行で", text: $title)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityIdentifier("main.title")
                Button(action: add) {
                    Text("道に出す")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Capsule().fill(canAdd ? Theme.skyDeep : Theme.sky))
                }
                .buttonStyle(PressStyle())
                .disabled(!canAdd)
                .accessibilityIdentifier("main.add")
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(focused ? Theme.sky : Theme.line, lineWidth: 1))

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(DeadlineChip.allCases) { option in
                        ChipButton(title: Self.label(option), selected: !useCustom && chip == option) {
                            model.select()
                            chip = option
                            useCustom = false
                        }
                    }
                    ChipButton(title: "日時", selected: useCustom, systemName: "calendar") {
                        model.select()
                        useCustom.toggle()
                    }
                    Rectangle().fill(Theme.line).frame(width: 1, height: 18).padding(.horizontal, 2)
                    ForEach(1...3, id: \.self) { w in
                        ChipButton(title: WeightLabel.key(w), selected: weight == w, dots: w) {
                            model.select()
                            weight = w
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            if useCustom {
                DatePicker("締め切り", selection: $customDate, in: model.now..., displayedComponents: [.date, .hourAndMinute])
                    .font(.system(size: 13))
                    .tint(Theme.skyDeep)
                    .foregroundStyle(Theme.ink)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: useCustom)
    }

    private var canAdd: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private func add() {
        guard canAdd else { return }
        let deadline = useCustom ? customDate : (chip ?? .tonight).deadline(from: model.now, calendar: model.calendar)
        model.add(title: title, deadline: deadline, weight: weight)
        title = ""
    }

    static func label(_ chip: DeadlineChip) -> LocalizedStringKey {
        switch chip {
        case .tonight: return "今夜"
        case .tomorrow: return "明日"
        case .thisWeek: return "今週"
        }
    }
}

struct ChipButton: View {
    let title: LocalizedStringKey
    let selected: Bool
    var systemName: String?
    var dots: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemName {
                    Image(systemName: systemName).font(.system(size: 11))
                }
                if let dots {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle().fill(i < dots ? (selected ? Theme.skyDeep : Theme.sub) : Theme.line).frame(width: 4, height: 4)
                        }
                    }
                }
                Text(title)
            }
            .font(.system(size: 13, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Theme.skyDeep : Theme.ink.opacity(0.75))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(selected ? Theme.skySoft : Theme.card))
            .overlay(Capsule().stroke(selected ? Theme.sky : Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
