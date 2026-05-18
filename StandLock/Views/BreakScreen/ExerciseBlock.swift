import SwiftUI
import StandLockCore

struct ExerciseBlock: View {
    let exercise: Exercise
    let palette: BreakPalette

    private var titleWithPeriod: String {
        exercise.title.hasSuffix(".") ? exercise.title : exercise.title + "."
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(titleWithPeriod)
                .font(BreakTypography.exerciseName())
                .tracking(-0.5)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)

            Text(exercise.description)
                .font(BreakTypography.exerciseBody())
                .foregroundStyle(palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(17 * 0.6)
                .frame(maxWidth: 560)
        }
    }
}
