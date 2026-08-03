import WidgetKit
import SwiftUI
import WidgetShared

@main
struct ByVPNWidgetBundle: WidgetBundle {
    var body: some Widget {
        ByVPNStatusWidget()

        if #available(iOSApplicationExtension 18.0, *) {
            ByVPNControlWidget()
        }
    }
}
