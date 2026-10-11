import Foundation

enum Endpoints {
    static let domain = Bundle.main.object(forInfoDictionaryKey: "Domain") as! String
    static let apiDomain = Bundle.main.object(forInfoDictionaryKey: "ApiDomain") as! String
    static let website = "https://\(domain)"
    static let appcastUrl = "https://raw.githubusercontent.com/mgabs/tab-flow/master/appcast.xml"
    static let supportUrl = "https://github.com/mgabs/tab-flow"
    static let licenseApiBaseUrl = "https://\(apiDomain)/v1/license"
    static let feedbackUrl = "https://\(apiDomain)/v1/feedback"
}
