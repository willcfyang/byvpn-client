import Foundation
import Theme

public enum GeneralByVpnError: Error, Equatable {
    case invalidUrl
    case cannotFetchCountries
    case noPrebundledCountries
    case library(message: String)
    case noMnemonicStored
    case noEnv
    case somethingWentWrong
    case authorizationDenied
}

extension GeneralByVpnError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidUrl:
            "generalByVpnError.invalidUrl".localizedString
        case .cannotFetchCountries:
            "generalByVpnError.cannotFetchCountries".localizedString
        case .noPrebundledCountries:
            "generalByVpnError.noPrebundledCountries".localizedString
        case .library(message: let message):
            message
        case .noMnemonicStored:
            "error.noMnemonicStored".localizedString
        case .noEnv:
            "generalByVpnError.noEnv".localizedString
        case .somethingWentWrong:
            "generalByVpnError.somethingWentWrong".localizedString
        case .authorizationDenied:
            "generalByVpnError.authorizationDenied".localizedString
        }
    }
}
