import Foundation
#if os(iOS) || os(visionOS)
import AdSupport
import UIKit
#endif

/// 加密文档中的设备字段。`idfv` / `idfa` 与文档里的 `UIDevice`、`Adjust.idfa()` 一致。
enum DeviceIdentity {
    static var sourceChannel: String { "" }

    static var adid: String { "" }

    static var idfa: String {
        #if os(iOS) || os(visionOS)
        ASIdentifierManager.shared().advertisingIdentifier.uuidString
        #else
        ""
        #endif
    }

    static var idfv: String {
        #if os(iOS) || os(visionOS)
        UIDevice.current.identifierForVendor?.uuidString ?? ""
        #else
        ""
        #endif
    }
}
