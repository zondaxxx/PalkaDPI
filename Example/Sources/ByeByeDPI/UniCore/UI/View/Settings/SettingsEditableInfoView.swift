//
//  SettingsInfoView.swift
//  SwByeDPI
//
//  Created by developer on 02.03.2026.
//

import SwiftUI

struct SettingsEditableInfoView: View {
    
    fileprivate let title: String
    @Binding fileprivate var value: String
    fileprivate let valueTextSuffix: String
    fileprivate let leadingIcon: Image
    fileprivate let keyboardType: AppKeyboardType
    fileprivate let autocapitalizationType: AppTextAutocapitalizationType
    @State fileprivate var showTextFieldAlert = false
    
    fileprivate let validator: ((String) -> Bool)?
    fileprivate let onNewValue: ((String) -> Void)?
    
    @State fileprivate var tfValue: String
    
    init(title: String, value: Binding<String>, leadingIcon: Image, valueTextSuffix: String = "", validator: ((String) -> Bool)? = nil, onNewValue:  ((String) -> Void)? = nil, keyboardType: AppKeyboardType = .defaultVal, autocapitalizationType: AppTextAutocapitalizationType = .sentences) {
        self.title = title
        _value = value
        _tfValue = State(initialValue: value.wrappedValue)
        self.valueTextSuffix = valueTextSuffix
        self.leadingIcon = leadingIcon
        self.validator = validator
        self.onNewValue = onNewValue
        self.keyboardType = keyboardType
        self.autocapitalizationType = autocapitalizationType
    }
    
    var body: some View {
        Button {
            showTextFieldAlert = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                PalkaIconBadge(image: leadingIcon)

                VStack(alignment: .leading, spacing: 4, content: {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(PalkaDesign.textMuted)
                    Text(value + valueTextSuffix)
                        .font(.system(size: 14, weight: .regular))
                        .monospacedDigit()
                        .multilineTextAlignment(.leading)
                        .foregroundColor(PalkaDesign.textPrimary)
                        .lineLimit(4)
                        .lineSpacing(3)
                })

                Spacer(minLength: 4)

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(PalkaDesign.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .palkaCard(radius: 16)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(PalkaPressButtonStyle())
        .textFieldAlert(isPresented: $showTextFieldAlert, text: $tfValue, title: title, autocapitalizationType: autocapitalizationType, keyboardType: keyboardType, validator: validator, onCancel: {
            tfValue = value
            showTextFieldAlert = false
        }, action: { newVal in
            if (newVal == value) {
                //Same enter -> no op
                tfValue = value
                showTextFieldAlert = false
                return
            }
            value = tfValue
            guard let safeOnNewValue = onNewValue else {
                showTextFieldAlert = false
                return
            }
            safeOnNewValue(newVal)
            showTextFieldAlert = false
        })
        .onAppear {
            tfValue = value
        }
    }
}

#Preview {
    var ipAddr = "127.0.0.1"
    var port = "10800"
    var dns = "8.8.8.8"
    var delayInS = "1"
    
    VStack(alignment: .leading, spacing: 12.0) {
        SettingsEditableInfoView(title: "Bind IP", value: Binding(get: {
            return ipAddr
        }, set: { newVal in
            ipAddr = newVal
        }), leadingIcon: Image(R.image.icWorld), keyboardType: .decimalPad)
        SettingsEditableInfoView(title: "Port", value: Binding(get: {
            return port
        }, set: { newVal in
            port = newVal
        }), leadingIcon: Image(R.image.icWorld), keyboardType: .numberPad)
        SettingsEditableInfoView(title: "DNS", value: Binding(get: {
            return dns
        }, set: { newVal in
            dns = newVal
        }), leadingIcon: Image(R.image.icWorld), keyboardType: .decimalPad)
        SettingsEditableInfoView(title: "Request delay", value: Binding(get: {
            return delayInS
        }, set: { newVal in
            delayInS = newVal
        }), leadingIcon: Image(R.image.icWorld), valueTextSuffix: " - More seconds improves test stability", keyboardType: .numberPad)
    }
}
