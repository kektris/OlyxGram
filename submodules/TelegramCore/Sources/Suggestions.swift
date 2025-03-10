import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public enum ServerProvidedSuggestion: String {
    case autoarchivePopular = "AUTOARCHIVE_POPULAR"
    case newcomerTicks = "NEWCOMER_TICKS"
    case validatePhoneNumber = "VALIDATE_PHONE_NUMBER"
    case validatePassword = "VALIDATE_PASSWORD"
    case setupPassword = "SETUP_PASSWORD"
    case upgradePremium = "PREMIUM_UPGRADE"
    case annualPremium = "PREMIUM_ANNUAL"
    case restorePremium = "PREMIUM_RESTORE"
    case xmasPremiumGift = "PREMIUM_CHRISTMAS"
    case setupBirthday = "BIRTHDAY_SETUP"
    case todayBirthdays = "BIRTHDAY_CONTACTS_TODAY"
    case gracePremium = "PREMIUM_GRACE"
    case starsSubscriptionLowBalance = "STARS_SUBSCRIPTION_LOW_BALANCE"
    case setupPhoto = "USERPIC_SETUP"
}

private var dismissedSuggestionsPromise = ValuePromise<[AccountRecordId: Set<ServerProvidedSuggestion>]>([:])
private var dismissedSuggestions: [AccountRecordId: Set<ServerProvidedSuggestion>] = [:] {
    didSet {
        dismissedSuggestionsPromise.set(dismissedSuggestions)
    }
}

func _internal_getServerProvidedSuggestions(account: Account) -> Signal<[ServerProvidedSuggestion], NoError> {
    let key: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.appConfiguration]))
    return combineLatest(account.postbox.combinedView(keys: [key]), dismissedSuggestionsPromise.get())
    |> map { views, dismissedSuggestionsValue -> [ServerProvidedSuggestion] in
        let dismissedSuggestions = dismissedSuggestionsValue[account.id] ?? Set()
        guard let view = views.views[key] as? PreferencesView else {
            return []
        }
        guard let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) else {
            return []
        }
        guard let data = appConfiguration.data, let listItems = data["pending_suggestions"] as? [String] else {
            return []
        }
        return listItems.compactMap { item -> ServerProvidedSuggestion? in
            return ServerProvidedSuggestion(rawValue: item)
        }.filter { !dismissedSuggestions.contains($0) }
    }
    |> distinctUntilChanged
}

func _internal_getServerDismissedSuggestions(account: Account) -> Signal<[ServerProvidedSuggestion], NoError> {
    let key: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.appConfiguration]))
    return combineLatest(account.postbox.combinedView(keys: [key]), dismissedSuggestionsPromise.get())
    |> map { views, dismissedSuggestionsValue -> [ServerProvidedSuggestion] in
        let dismissedSuggestions = dismissedSuggestionsValue[account.id] ?? Set()
        guard let view = views.views[key] as? PreferencesView else {
            return []
        }
        guard let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) else {
            return []
        }
        var listItems: [String] = []
        if let data = appConfiguration.data, let listItemsValues = data["dismissed_suggestions"] as? [String] {
            listItems.append(contentsOf: listItemsValues)
        }
        var items = listItems.compactMap { item -> ServerProvidedSuggestion? in
            return ServerProvidedSuggestion(rawValue: item)
        }
        items.append(contentsOf: dismissedSuggestions)
        return items
    }
    |> distinctUntilChanged
}

func _internal_dismissServerProvidedSuggestion(account: Account, suggestion: ServerProvidedSuggestion) -> Signal<Never, NoError> {
    if let _ = dismissedSuggestions[account.id] {
        dismissedSuggestions[account.id]?.insert(suggestion)
    } else {
        dismissedSuggestions[account.id] = Set([suggestion])
    }
    return account.network.request(Api.functions.help.dismissSuggestion(peer: .inputPeerEmpty, suggestion: suggestion.rawValue))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> ignoreValues
}


public enum PeerSpecificServerProvidedSuggestion: String {
    case convertToGigagroup = "CONVERT_GIGAGROUP"
}

func _internal_getPeerSpecificServerProvidedSuggestions(postbox: Postbox, peerId: PeerId) -> Signal<[PeerSpecificServerProvidedSuggestion], NoError> {
    return postbox.peerView(id: peerId)
    |> map { view in
        if let cachedData = view.cachedData as? CachedChannelData {
            return cachedData.pendingSuggestions.compactMap { item -> PeerSpecificServerProvidedSuggestion? in
                return PeerSpecificServerProvidedSuggestion(rawValue: item)
            }
        }
        return []
    }
    |> distinctUntilChanged
}

func _internal_dismissPeerSpecificServerProvidedSuggestion(account: Account, peerId: PeerId, suggestion: PeerSpecificServerProvidedSuggestion) -> Signal<Never, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> mapToSignal { peer -> Signal<Never, NoError> in
        guard let inputPeer = apiInputPeer(peer) else {
            return .never()
        }
        return account.network.request(Api.functions.help.dismissSuggestion(peer: inputPeer, suggestion: suggestion.rawValue))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { a -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction in
                transaction.updatePeerCachedData(peerIds: [peerId]) { (_, current) -> CachedPeerData? in
                    var updated = current
                    if let cachedData = current as? CachedChannelData {
                        var pendingSuggestions = cachedData.pendingSuggestions
                        pendingSuggestions.removeAll(where: { $0 == suggestion.rawValue })
                        updated = cachedData.withUpdatedPendingSuggestions(pendingSuggestions)
                    }
                    return updated
                }
            } |> ignoreValues
        }
    }
}


// MARK: Swiftgram
private var dismissedSGSuggestionsPromise = ValuePromise<Set<String>>(Set())
private var dismissedSGSuggestions: Set<String> = Set() {
    didSet {
        dismissedSGSuggestionsPromise.set(dismissedSGSuggestions)
    }
}


public func dismissSGProvidedSuggestion(suggestionId: String) {
    dismissedSGSuggestions.insert(suggestionId)
}

public func getSGProvidedSuggestions(account: Account) -> Signal<Data?, NoError> {
    let key: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.appConfiguration]))

    return combineLatest(account.postbox.combinedView(keys: [key]), dismissedSGSuggestionsPromise.get())
    |> map { views, dismissedSuggestionsValue -> Data? in
        guard let view = views.views[key] as? PreferencesView else {
            return nil
        }
        guard let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) else {
            return nil
        }
        guard let announcementsString = appConfiguration.sgWebSettings.global.announcementsData,
              let announcementsData = announcementsString.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let suggestions = try JSONSerialization.jsonObject(with: announcementsData, options: []) as? [[String: Any]] {
                let filteredSuggestions = suggestions.filter { suggestion in
                    guard let id = suggestion["id"] as? String else {
                        return true
                    }
                    return !dismissedSuggestionsValue.contains(id)
                }
                let modifiedData = try JSONSerialization.data(withJSONObject: filteredSuggestions, options: [])
                return modifiedData
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    |> distinctUntilChanged
}


