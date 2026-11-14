import SwiftUI

struct MathProblem: Hashable {
    let text: String
    let result: Int

    static func random(hard: Bool) -> MathProblem {
        switch Int.random(in: 0..<3) {
        case 0:
            let a = Int.random(in: hard ? 25...99 : 12...59)
            let b = Int.random(in: hard ? 25...99 : 11...39)
            return MathProblem(text: "\(a) + \(b)", result: a + b)
        case 1:
            let a = Int.random(in: hard ? 50...99 : 30...79)
            let b = Int.random(in: 11...(a - 1))
            return MathProblem(text: "\(a) − \(b)", result: a - b)
        default:
            let a = Int.random(in: hard ? 6...12 : 3...9)
            let b = Int.random(in: hard ? 12...25 : 6...15)
            return MathProblem(text: "\(a) × \(b)", result: a * b)
        }
    }
}

struct MathChallengeView: View {
    let count: Int
    var hard = false
    let onDone: () -> Void

    @State private var problems: [MathProblem] = []
    @State private var index = 0
    @State private var answer = ""
    @State private var wrong = 0
    @State private var solved = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 18) {
            SectionLabel("Cuenta \(min(index + 1, count)) de \(count)")

            if index < problems.count {
                Text(problems[index].text)
                    .font(Theme.clock(48))
                    .foregroundStyle(Theme.text)
                    .accessibilityLabel(problems[index].text.replacingOccurrences(of: "×", with: "por").replacingOccurrences(of: "−", with: "menos"))
            }

            TextField("Resultado", text: $answer)
                .keyboardType(.numberPad)
                .font(Theme.clock(34))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.text)
                .focused($focused)
                .frame(minHeight: 64)
                .pipoCard(radius: Theme.smallRadius)
                .onSubmit(check)

            if wrong > 0 {
                Text("Casi. Prueba otra vez.")
                    .font(Theme.body(.subheadline, .semibold))
                    .foregroundStyle(Theme.primaryText)
            }

            Button("Comprobar", action: check)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(answer.isEmpty)
        }
        .onAppear {
            if problems.isEmpty {
                problems = (0..<count).map { _ in MathProblem.random(hard: hard) }
            }
            focused = true
        }
        .sensoryFeedback(.error, trigger: wrong)
        .sensoryFeedback(.success, trigger: solved)
    }

    private func check() {
        guard index < problems.count, let value = Int(answer.trimmingCharacters(in: .whitespaces)) else { return }
        if value == problems[index].result {
            solved += 1
            index += 1
            answer = ""
            if index >= problems.count {
                focused = false
                onDone()
            }
        } else {
            wrong += 1
            answer = ""
        }
    }
}
