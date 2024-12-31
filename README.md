<a href="https://canopas.com/contact"> <img src="./Screenshots/banner.png"></a>

# Splito - Divide, Conquer & Enjoy Together! 💰
Simplifying group expense management is easy and fair among friends and family with advanced tracking, splitting, and settlement features.

<img src="./Screenshots/SplitoCover.png"/>

## Overview

Splito is an open-source expense tracking and splitting application inspired by Splitwise. It simplifies the management of shared expenses 💰, making it easy for users to track 📈, split, and settle costs among friends, family, or group members 👫.

Whether it's a group trip 🌍, shared household bills 🏠, or any other collective expense, Splito ensures fairness and transparency in cost-sharing with its user-friendly interface and robust features. Users can effortlessly manage debts and settle up 💳 payments within their groups 👥.

## Download App 
<a href="https://apps.apple.com/in/app/splito-split-enjoy-together/id6477442217"> <img src="./Screenshots/AppStore.png" width="200"></img> </a>

## Features🌟

Splito is currently in active development 🚧, with plans to incorporate additional features shortly.

- **Group Management:** Create and manage multiple expense groups 👥 for different purposes (e.g., games, trips, shared bills).
- **Expense Tracking:** Add expenses 💰 with details such as description, amount, payer, and date.
- **Expense Splitting:** Split expenses equally⚖️ or based on customizable ratios among group members.
- **Payment Settlement:** Easily settle 💳 the payments with other group members to clear outstanding balances.

<details>
  <summary> How to Use Splito </summary>

  ## How to Use Splito
  
- Create a Group ➕:
  - Start by creating a new expense group for your specific need (e.g., a trip to Goa, monthly utilities).
- Add Members 👥:
  - Invite friends, family, or colleagues to join the group.
- Track Expenses 📈:
  - Add expenses as they occur, detailing the amount, who paid, and any relevant notes.
- Split Costs⚖️:
  - It uses flexible splitting options to divide expenses fairly among group members.
- Payment Settlements 💳:
  - Settle up the payment with any other group member as any payment occurs.

</details>

## Screenshots
<table>
  <tr>
    <th width="32%"> Group List </th>
    <th width="32%"> Group Expense List </th>
    <th width="32%"> Expense Add/Edit </th>
  </tr>
  <tr>
    <td> <img src="./Screenshots/GroupList.png" /> </td>
    <td> <img src="./Screenshots/GroupHome.png"/> </td>
    <td> <img src="./Screenshots/AddExpense.png"/> </td>
  </tr>  
</table>
<table>
  <tr>
    <th width="32%"> Expense Split Option </th>
    <th width="32%"> Expense Detail </th>
    <th width="32%"> Group Balance </th>
  </tr>
  <tr>
    <td> <img src="./Screenshots/SplitOptions.png"/> </td>
    <td> <img src="./Screenshots/ExpenseDetail.png"/> </td>
    <td> <img src="./Screenshots/GroupBalance.png"/> </td>
  </tr>  
</table>
<table>
  <tr>
    <th width="32%"> Group Summary </th>
    <th width="32%"> Activity Log History </th>
    <th width="32%"> Payment List </th>
  </tr>
  <tr>
    <td> <img src="./Screenshots/GroupSummary.png"/> </td>
    <td> <img src="./Screenshots/ActivityLogs.png"/> </td>
    <td> <img src="./Screenshots/Transactions.png"/> </td>
  </tr>
</table>
<table>
  <tr>
    <th width="32%"> Payment Add/Edit </th>
    <th width="32%"> Payment Detail </th>
    <th> </th>
  </tr>
  <tr>
    <td> <img src="./Screenshots/GroupPayment.png"/> </td>
    <td> <img src="./Screenshots/TransactionDetail.png"/> </td>
    <td> </td>
  </tr>
</table>

## Requirements ✅
Make sure you have the latest stable version of Xcode installed. Then, you can clone this repository to Xcode.

To run Splito locally, you'll need:
- iOS (version 16.4 or higher)
- Xcode (version 15.4 or higher)

<details>
  <summary> Firebase Setup </summary>

## Firebase Setup 🚀

To enable Firebase services, you will need to create a new project in the Firebase Console. Use the app bundle ID value specified in the project setting in Xcode. Once the project is created, you will need to add the GoogleService-Info.plist file to the project. For more information, refer to the [Firebase documentation](https://firebase.google.com/docs/ios/setup).

Splito uses the following Firebase services, Make sure you enable them in your Firebase project:

- Authentication (Phone, Google and Apple login)
- Firestore (To store user data)

</details>

## Tech stack 📚
Splito utilizes the latest iOS technologies and adheres to industry best practices. Below is the current tech stack used in the development process:
- MVVM Architecture
- SwiftUI
- Concurrency
- Combine + Swift
- Swinject for DI
- SwiftLint for Lint
- Cloud Functions
- Firebase Firestore
- Firebase Authentication
- CocoaLumberjack for Logging

## Contribution 🤝
The Canopas team enthusiastically welcomes contributions and project participation! There are a bunch of things you can do if you want to contribute! The [Contributor Guide](CONTRIBUTING.md) has all the information you need for everything from reporting bugs to contributing entire new features. Please don't hesitate to jump in if you'd like to, or even ask us questions if something isn't clear.

## Credits
Splito is owned and maintained by the [Canopas team](https://canopas.com/). You can follow them on X at [@canopassoftware](https://x.com/canopassoftware) for project updates and releases. If you are interested in building apps or designing products, please let us know. We'd love to hear from you!

<a href="https://canopas.com/contact"><img src="./Screenshots/cta.png" width=250></a>

## License 📄

**Splito** is licensed under the Apache License, Version 2.0.

```
Copyright 2024 Canopas Software LLP

Licensed under the Apache License, Version 2.0 (the "License");
You won't be using this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
