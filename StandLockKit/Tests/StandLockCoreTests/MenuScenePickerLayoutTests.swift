import Testing
@testable import StandLockCore

@Suite("Menu Scene Picker Layout Tests")
struct MenuScenePickerLayoutTests {

    private let allScenes = MenuScenePickerLayout.order

    @Test func offIsTheFirstCardAndEverySceneIsListedOnce() {
        #expect(allScenes.first == .off)
        #expect(Set(allScenes) == Set(MenuScene.allCases))
        #expect(allScenes.count == MenuScene.allCases.count)
    }

    @Test func twoRowsShowFiveScenesAndAPlusCardWhileMoreAreLeft() {
        // Holds as long as there are more than six cards, which the pixel scenes made true.
        let (scenes, hasMore) = MenuScenePickerLayout.cards(rows: 2)

        #expect(scenes == Array(allScenes.prefix(5)))
        #expect(hasMore)
    }

    @Test func eachPressOpensARowAndKeepsTheCardsAlreadyShown() {
        let two = MenuScenePickerLayout.cards(rows: 2).scenes
        let (three, moreAfterThree) = MenuScenePickerLayout.cards(rows: 3)

        // Three more scenes, or every scene when the "+" card's own slot is no longer needed.
        #expect(three.count == (moreAfterThree ? two.count + 3 : allScenes.count))
        #expect(Array(three.prefix(two.count)) == two)
    }

    @Test func thePlusCardGoesOnceEverySceneFits() {
        let rows = (allScenes.count + 2) / 3
        let (scenes, hasMore) = MenuScenePickerLayout.cards(rows: rows)

        #expect(scenes == allScenes)
        #expect(!hasMore)
    }

    @Test func aHiddenSelectedSceneOpensEnoughRowsToShowIt() {
        for scene in allScenes {
            let rows = MenuScenePickerLayout.rows(showing: scene)
            #expect(MenuScenePickerLayout.cards(rows: rows).scenes.contains(scene))
            #expect(rows == 2 || !MenuScenePickerLayout.cards(rows: rows - 1).scenes.contains(scene))
        }
    }
}
