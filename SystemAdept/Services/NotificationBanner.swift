//  NotificationBanner.swift
//  SystemAdept
//
//  Created by ChatGPT on 4/26/25. (add your own name/date)
//

import SwiftUI

struct NotificationBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(8)
            .shadow(radius: 4)
            .padding(.horizontal)
    }
}

struct NotificationBanner_Previews: PreviewProvider {
    static var previews: some View {
        NotificationBanner(message: "Sample notification")
    }
}
