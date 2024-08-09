//
//  PhoneLoginView.swift
//  Splito
//
//  Created by Amisha Italiya on 22/02/24.
//

import Data
import SwiftUI
import BaseStyle

public struct PhoneLoginView: View {

    @StateObject var viewModel: PhoneLoginViewModel

    public var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        AppLogoView(geometry: .constant(proxy))

                        Text("What’s your phone number?")
                            .font(.Header1())
                            .foregroundStyle(primaryText)
                            .padding(.horizontal, 16)

                        VSpacer(16)

                        Text("We’ll verify your phone number with a verification code.")
                            .font(.subTitle1())
                            .foregroundStyle(disableText)
                            .tracking(-0.2)
                            .lineSpacing(4)
                            .padding(.horizontal, 16)

                        VSpacer(40)

                        HStack(spacing: 0) {
                            Spacer()

                            PhoneLoginContentView(phoneNumber: $viewModel.phoneNumber, countries: $viewModel.countries,
                                                  selectedCountry: $viewModel.currentCountry, showLoader: viewModel.showLoader)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                GetOtpBtnView(phoneNumber: $viewModel.phoneNumber, showLoader: viewModel.showLoader, onNext: viewModel.verifyAndSendOtp)
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            BackButton(onClick: viewModel.handleBackBtnTap)
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

private struct GetOtpBtnView: View {
    let MIN_NUMBER_LENGTH: Int = 4
    let MAX_NUMBER_LENGTH: Int = 20

    @Binding var phoneNumber: String

    let showLoader: Bool
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Group {
                Text("By entering your number, you’re agreeing to our ")
                    .foregroundColor(disableText)
                + Text("terms of service")
                    .foregroundColor(primaryText)
                + Text(" and ")
                    .foregroundColor(disableText)
                + Text("privacy policy.")
                    .foregroundColor(primaryText)
            }
            .font(.caption1())
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryButton(text: "Get OTP", isEnabled: (phoneNumber.count >= MIN_NUMBER_LENGTH && phoneNumber.count <= MAX_NUMBER_LENGTH), showLoader: showLoader, onClick: onNext)

            VSpacer(24)
        }
        .padding(.horizontal, 16)
    }
}

private struct PhoneLoginContentView: View {

    @Binding var phoneNumber: String
    @Binding var countries: [Country]
    @Binding var selectedCountry: Country

    let showLoader: Bool

    @State var showCountryPicker = false
    @FocusState var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(selectedCountry.dialCode)
                        .font(.subTitle1())
                        .foregroundStyle(primaryText)
                        .tracking(-0.2)

                    ScrollToTopButton(icon: "chevron.down", iconColor: primaryText, bgColor: surfaceColor, size: (12, 7.5), padding: 3, onClick: {
                        showCountryPicker = true
                    })
                }
                .onTapGestureForced {
                    showCountryPicker = true
                }

                Divider()
                    .frame(height: 50)
                    .background(dividerColor)
                    .padding(.horizontal, 16)

                ZStack(alignment: .leading) {
                    if phoneNumber.isEmpty {
                        Text(" Enter mobile number")
                            .font(.subTitle3())
                            .foregroundColor(disableText)
                    }
                    TextField("", text: $phoneNumber)
                        .font(.Header2())
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .foregroundStyle(primaryText)
                        .disabled(showLoader)
                        .accentColor(primaryColor)
                        .focused($isFocused)
                        .onAppear {
                            isFocused = true
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showCountryPicker) {
            PhoneLoginCountryPicker(countries: $countries, selectedCountry: $selectedCountry, isPresented: $showCountryPicker)
        }
    }
}

private struct PhoneLoginCountryPicker: View {

    @Binding var countries: [Country]
    @Binding var selectedCountry: Country
    @Binding var isPresented: Bool

    @State private var searchCountry: String = ""
    @FocusState private var isFocused: Bool

    private var filteredCountries: [Country] {
        countries.filter { country in
            searchCountry.isEmpty ? true : country.name.lowercased().contains(searchCountry.lowercased()) ||
            country.dialCode.lowercased().contains(searchCountry.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Countries")
                .font(.Header4())
                .foregroundStyle(primaryText)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .center)
                .onTapGestureForced {
                    isFocused = false
                }

            SearchBar(text: $searchCountry, isFocused: $isFocused, placeholder: "Search")
                .padding(.vertical, -7)
                .padding(.horizontal, 3)
                .overlay(content: {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(outlineColor, lineWidth: 1)
                })
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }
                .padding([.horizontal, .bottom], 16)

            if filteredCountries.isEmpty {
                CountryNotFoundView(searchCountry: searchCountry)
            } else {
                List(filteredCountries) { country in
                    PhoneLoginCountryCell(country: country) {
                        selectedCountry = country
                        isPresented = false
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

private struct CountryNotFoundView: View {

    let searchCountry: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("No results found for \"\(searchCountry)\"!")
                .font(.subTitle1())
                .foregroundColor(disableText)
                .padding(.bottom, 60)

            Spacer()
        }
        .onTapGestureForced {
            UIApplication.shared.endEditing()
        }
    }
}

private struct PhoneLoginCountryCell: View {

    let country: Country
    let onCellSelect: () -> Void

    var body: some View {
        Button(action: onCellSelect) {
            HStack(spacing: 0) {
                Text(country.flag + " " + country.name)
                    .font(.body1(16))
                    .foregroundStyle(primaryText)
                Spacer()
                Text(country.dialCode)
                    .font(.body1(16))
                    .foregroundStyle(primaryText)
            }
        }
    }
}
