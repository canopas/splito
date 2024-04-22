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

    @ObservedObject var viewModel: PhoneLoginViewModel

    public var body: some View {
        VStack(spacing: 0) {
            if case .loading = viewModel.currentState {
                LoaderView()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        VSpacer(50)

                        Text("Splito")
                            .font(.Header1(40))
                            .foregroundStyle(primaryColor)

                        Spacer(minLength: 40)

                        VStack(spacing: 16) {
                            SubtitleTextView(text: "Enter phone number", fontSize: .Header1(), fontColor: primaryText)

                            Text("We'll verify your phone number with a verification code")
                                .font(.subTitle2())
                                .foregroundStyle(disableText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        .padding(.horizontal, 16)

                        VSpacer(40)

                        HStack(spacing: 0) {
                            Spacer()
                            PhoneLoginContentView(phoneNumber: $viewModel.phoneNumber, countries: $viewModel.countries,
                                                  selectedCountry: $viewModel.currentCountry, showLoader: viewModel.showLoader,
                                                  onNext: viewModel.verifyAndSendOtp)
                            .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(surfaceColor)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toastView(toast: $viewModel.toast)
        .navigationBarTitle("", displayMode: .inline)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

private struct PhoneLoginContentView: View {
    let MIN_NUMBER_LENGTH: Int = 4
    let MAX_NUMBER_LENGTH: Int = 20

    @Binding var phoneNumber: String
    @Binding var countries: [Country]
    @Binding var selectedCountry: Country

    let showLoader: Bool
    let onNext: () -> Void

    @State var showCountryPicker = false

    @FocusState var isFocused: Bool

    var body: some View {
        VStack(spacing: 40) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text(selectedCountry.dialCode)
                        .font(.subTitle1())
                        .foregroundStyle(secondaryText)

                    Image(.downArrow)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24, alignment: .center)
                }
                .onTapGestureForced {
                    showCountryPicker = true
                }

                HStack(spacing: 20) {
                    Divider()
                        .frame(width: 1)
                        .overlay(outlineColor)

                    TextField("Phone number", text: $phoneNumber)
                        .font(.subTitle1())
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
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(lineWidth: 1)
                    .foregroundStyle(containerHighColor)
            )
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryButton(text: "Next", isEnabled: (phoneNumber.count >= MIN_NUMBER_LENGTH && phoneNumber.count <= MAX_NUMBER_LENGTH),
                          showLoader: showLoader, onClick: onNext)
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

    private var filteredCountries: [Country] {
        countries.filter { country in
            searchCountry.isEmpty ? true : country.name.lowercased().contains(searchCountry.lowercased()) ||
            country.dialCode.lowercased().contains(searchCountry.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Countries")
                .font(.headline)
                .padding(.top, 24)

            SearchBar(text: $searchCountry, placeholder: "Search")

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
