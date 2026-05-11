import SwiftUI
import StandLockCore

struct ExerciseSuggestionView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.title)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.white)

            Text(exercise.description)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 400, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.08))
        )
    }
}
