import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import PasswordSetupUI
import ItemListUI
import TelegramPresentationData

public protocol SettingsController: AnyObject {
    func updateContext(context: AccountContext)
}

public func makePrivacyAndSecurityController(context: AccountContext) -> ViewController {
    return privacyAndSecurityController(context: context, focusOnItemTag: PrivacyAndSecurityEntryTag.autoArchive)
}

public func makeBioPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, present: @escaping (ViewController) -> Void) {
    let signal = settings.get()
    |> take(1)
    |> deliverOnMainQueue
    
    let _ = signal.startStandalone(next: { info in
        if let info = info {
            present(selectivePrivacySettingsController(context: context, kind: .bio, current: info.bio, updated: { updated, _, _, _ in
                let applySetting: Signal<Void, NoError> = settings.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { value -> Signal<Void, NoError> in
                    if let value = value {
                        settings.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: updated, birthday: value.birthday, giftsAutoSave: value.giftsAutoSave, noPaidMessages: value.noPaidMessages, savedMusic: value.savedMusic,  globalSettings: value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                    }
                    return .complete()
                }
                let _ = applySetting.startStandalone()
            }))
        }
    })
}

public func makeBirthdayPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, openedFromBirthdayScreen: Bool, present: @escaping (ViewController) -> Void) {
    let signal = settings.get()
    |> take(1)
    |> deliverOnMainQueue
    
    let _ = signal.startStandalone(next: { info in
        if let info = info {
            present(selectivePrivacySettingsController(context: context, kind: .birthday, current: info.birthday, openedFromBirthdayScreen: openedFromBirthdayScreen, updated: { updated, _, _, _ in
                let applySetting: Signal<Void, NoError> = settings.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { value -> Signal<Void, NoError> in
                    if let value = value {
                        settings.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, birthday: updated, giftsAutoSave: value.giftsAutoSave, noPaidMessages: value.noPaidMessages, savedMusic: value.savedMusic, globalSettings: value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                    }
                    return .complete()
                }
                let _ = applySetting.startStandalone()
            }))
        }
    })
}

public func makeSetupTwoFactorAuthController(context: AccountContext) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let controller = TwoFactorAuthSplashScreen(sharedContext: context.sharedContext, engine: .authorized(context.engine), mode: .intro(.init(
        title: presentationData.strings.TwoFactorSetup_Intro_Title,
        text: presentationData.strings.TwoFactorSetup_Intro_Text,
        actionText: presentationData.strings.TwoFactorSetup_Intro_Action,
        doneText: presentationData.strings.TwoFactorSetup_Done_Action,
        phoneNumber: nil
    )))
    return controller
}

private final class ExteraPortSettingsArguments {
    let update: (Int32, Bool) -> Void

    init(update: @escaping (Int32, Bool) -> Void) {
        self.update = update
    }
}

private enum ExteraPortSettingsEntry: ItemListNodeEntry {
    case toggle(Int32, String, Bool)
    case footer(String)

    var section: ItemListSectionId { return 0 }

    var stableId: Int32 {
        switch self {
        case let .toggle(index, _, _): return index
        case .footer: return 100
        }
    }

    static func < (lhs: ExteraPortSettingsEntry, rhs: ExteraPortSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ExteraPortSettingsArguments
        switch self {
        case let .toggle(index, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update(index, value)
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

public func exteraPortSettingsController(context: AccountContext) -> ViewController {
    let keys = ["exteraPort.showMessageDetails", "exteraPort.hideOwnPhoneNumber", "exteraPort.hideStories"]
    let defaults = [true, false, false]
    let readValues: () -> [Bool] = {
        return keys.enumerated().map { index, key in
            return UserDefaults.standard.object(forKey: key) as? Bool ?? defaults[index]
        }
    }
    let values = ValuePromise<[Bool]>(readValues(), ignoreRepeated: true)
    let arguments = ExteraPortSettingsArguments(update: { index, value in
        guard keys.indices.contains(Int(index)) else { return }
        UserDefaults.standard.set(value, forKey: keys[Int(index)])
        values.set(readValues())
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        values.get()
    )
    |> map { presentationData, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isRussian = (Locale.current.languageCode ?? "en") == "ru"
        let titles = isRussian
            ? ["Данные сообщения", "Скрывать номер в шапке настроек", "Скрывать истории над чатами"]
            : ["Message details", "Hide phone number in settings header", "Hide stories above chats"]
        let title = isRussian ? "Настройки мода" : "Mod settings"
        let footer = isRussian
            ? "После изменения перезапустите приложение. Параметры действуют для всех аккаунтов на этом устройстве."
            : "Restart the app after changing these options. Options apply to all accounts on this device."
        var entries: [ExteraPortSettingsEntry] = []
        for (index, label) in titles.enumerated() {
            entries.append(.toggle(Int32(index), label, values[index]))
        }
        entries.append(.footer(footer))
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
