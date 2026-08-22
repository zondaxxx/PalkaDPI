//
//  SettingsInfoView.swift
//  SwByeDPI
//
//  Created by developer on 02.03.2026.
//

import SwiftUI

struct SettingsButtonView: View {
    
    fileprivate let title: String
    fileprivate let text: String
    fileprivate let leadingIcon: Image
    
    fileprivate let onPressed: () -> Void
    
    init(title: String, text: String, leadingIcon: Image, onPressed: @escaping () -> Void) {
        self.title = title
        self.text = text
        self.leadingIcon = leadingIcon
        self.onPressed = onPressed
    }
    
    var body: some View {
        Button(action: onPressed) {
            HStack(alignment: .center, spacing: 12) {
                PalkaIconBadge(image: leadingIcon)

                VStack(alignment: .leading, spacing: 4, content: {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(PalkaDesign.textMuted)
                    Text(text)
                        .font(.system(size: 14, weight: .regular))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(PalkaDesign.textPrimary)
                        .lineSpacing(3)
                })

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(PalkaDesign.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .palkaCard(radius: 16)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(PalkaPressButtonStyle())
    }
}

#Preview {
    SettingsButtonView(title: "Some category", text: "Category Value", leadingIcon: Image(R.image.icInfo)) {
        
    }
}
