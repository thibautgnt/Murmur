import Foundation
import Testing
@testable import VoiceInk

@Suite("Murmur defaults")
struct MurmurDefaultsTests {
    @Test func registeredDefaultsKeepMurmurChoices() {
        AppDefaults.registerDefaults()
        let registered = UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)

        #expect(registered["SelectedLanguage"] as? String == "fr")
        #expect(registered["RecorderType"] as? String == "notch")
        #expect(registered["IsMenuBarOnly"] as? Bool == true)
        #expect(registered["ShowMenuBarIcon"] as? Bool == false)
        #expect(registered["isSystemMuteEnabled"] as? Bool == false)
    }

    @Test func pasteMethodDefaultsToDirectTyping() throws {
        let suite = "MurmurDefaultsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(PasteMethod.current(in: defaults) == .directTyping)
    }
}

@Suite("Paste method in Electron apps")
struct ElectronPasteTests {
    private func makeBundle(electron: Bool) throws -> URL {
        let bundle = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Sample.app")
        var frameworks = bundle.appendingPathComponent("Contents/Frameworks")
        if electron { frameworks.appendPathComponent("Electron Framework.framework") }
        try FileManager.default.createDirectory(at: frameworks, withIntermediateDirectories: true)
        return bundle
    }

    @Test func directTypingFallsBackToPasteInElectronApps() throws {
        let bundle = try makeBundle(electron: true)
        #expect(CursorPaster.resolvedMethod(.directTyping, forBundleAt: bundle) == .standard)
    }

    @Test func directTypingIsKeptInNativeApps() throws {
        let bundle = try makeBundle(electron: false)
        #expect(CursorPaster.resolvedMethod(.directTyping, forBundleAt: bundle) == .directTyping)
        #expect(CursorPaster.resolvedMethod(.directTyping, forBundleAt: nil) == .directTyping)
    }

    @Test(arguments: [PasteMethod.standard, .appleScript, .remoteTyping])
    func otherMethodsAreNeverChanged(_ method: PasteMethod) throws {
        let bundle = try makeBundle(electron: true)
        #expect(CursorPaster.resolvedMethod(method, forBundleAt: bundle) == method)
    }
}

@Suite("VoiceInk Refine language")
struct RefineLanguageTests {
    @Test func englishAnswerToFrenchDictationIsATranslation() {
        #expect(VoiceInkRefineService.isTranslation(
            of: "On va envoyer ça en prod sans attendre d'avocats",
            "We are going to send it to production without waiting for lawyers."))
        #expect(VoiceInkRefineService.isTranslation(of: "Vas-y installe-le.", "Install it."))
    }

    @Test func frenchWithEnglishWordsIsKept() {
        #expect(!VoiceInkRefineService.isTranslation(
            of: "euh change le skill s'il faut",
            "Change le skill s'il faut."))
        #expect(!VoiceInkRefineService.isTranslation(
            of: "on push le fix sur la branche main et on merge la PR",
            "On push le fix sur la branche main et on merge la PR."))
    }
}
