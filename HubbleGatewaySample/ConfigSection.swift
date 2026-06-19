import SwiftUI

struct ConfigSection: View {
    @Bindable var model: AppModel

    var body: some View {
        LabeledContent("API base URL") {
            TextField("https://gw-api.hubble.com", text: $model.apiBaseURLString)
                .multilineTextAlignment(.trailing)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}
