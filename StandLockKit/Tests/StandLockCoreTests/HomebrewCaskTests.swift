import Testing
@testable import StandLockCore

@Suite("Homebrew Cask Tests")
struct HomebrewCaskTests {
    private let cask = """
    cask "standlock" do
      version "0.11.0"
      sha256 "17f7e904d55d2e12430b3a78386ac4ff0130dbc92f7087701814bb07dd52d461"

      url "https://github.com/yagizdo/StandLock/releases/download/v#{version}/StandLock-#{version}.dmg"
      name "StandLock"
    end
    """

    @Test func aCaskBodyGivesItsVersion() {
        #expect(HomebrewCask.version(inCaskSource: cask) == "0.11.0")
    }

    @Test func aBodyWithNoVersionLineGivesNothing() {
        #expect(HomebrewCask.version(inCaskSource: "cask \"standlock\" do\nend") == nil)
    }

    @Test func aCommentedVersionIsNotRead() {
        #expect(HomebrewCask.version(inCaskSource: "# version \"9.9.9\"\n") == nil)
    }

    @Test func aWordEndingInVersionIsNotRead() {
        #expect(HomebrewCask.version(inCaskSource: "  minimum_version \"9.9.9\"\n") == nil)
    }

    @Test func anEmptyVersionGivesNothing() {
        #expect(HomebrewCask.version(inCaskSource: "  version \"\"\n") == nil)
    }

    @Test func aTwoDigitMinorIsNewerThanASingleDigitOne() {
        #expect(HomebrewCask.isNewer("0.10.0", than: "0.9.0"))
    }

    @Test func aVersionIsNotNewerThanItself() {
        #expect(!HomebrewCask.isNewer("0.11.0", than: "0.11.0"))
    }

    @Test func anOlderVersionIsNotNewer() {
        #expect(!HomebrewCask.isNewer("0.9.0", than: "0.10.0"))
    }

    @Test func noDiskVersionMeansTheUpgradeDidNotLand() {
        #expect(!HomebrewCask.upgradeLanded(target: "0.11.0", diskVersion: nil))
    }

    @Test func anOlderDiskVersionMeansTheUpgradeDidNotLand() {
        #expect(!HomebrewCask.upgradeLanded(target: "0.11.0", diskVersion: "0.10.1"))
    }

    @Test func theTargetVersionOnDiskMeansTheUpgradeLanded() {
        #expect(HomebrewCask.upgradeLanded(target: "0.11.0", diskVersion: "0.11.0"))
    }

    @Test func aNewerDiskVersionMeansTheUpgradeLanded() {
        #expect(HomebrewCask.upgradeLanded(target: "0.11.0", diskVersion: "0.11.1"))
    }
}
