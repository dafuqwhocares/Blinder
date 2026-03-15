import SwiftUI

struct AboutView: View {
    
    let icon: NSImage
    let name: String
    let version: String
    let build: String
    let copyright: String
    let developerName: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(nsImage: icon)
                .padding()
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(.title)
                        .bold()
                    Spacer()
                    Text("Version \(version)") + Text(" (\(build))")
                }
                Divider()
                    .padding(.top, -8)
                Text("About Blinder App")
                    .bold()
                    .padding(.top, 2)
                Text("Blinder is built for research workflows that require objective, blinded file review. It anonymizes file names while preserving a secure mapping so data can be restored reliably at any time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)
                Text("Developed by")
                    .bold()
                    .padding(.bottom, 2)
                Text(developerName)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.bottom, 12)
                Spacer()
                Text(copyright)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }.padding(EdgeInsets(top: 20, leading: 0, bottom: 14, trailing: 30))
        }
    }
}
