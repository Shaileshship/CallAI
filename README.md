# CallAI

CallAI is an AI-powered cold-calling assistant app built with Flutter. It automates and enhances the process of making sales or support calls by leveraging advanced AI models (Gemini, DeepSeek, ChatGPT) for real-time conversation, script refinement, and result analysis. The app features a wallet system, flexible payment, and user-selectable AI quality.

## Features

- **AI-Powered Cold Calling:**
  - Upload a contact list (Excel/CSV) and let the app handle calls with AI-generated scripts and responses.
  - Choose AI quality (Normal, Medium, Best) with different providers and prices.
  - Real-time speech-to-text (STT) and text-to-speech (TTS) for natural conversations.
- **Script Refinement:**
  - AI helps refine your sales pitch or call script before starting calls.
- **Wallet & Payment System:**
  - 5 free calls for new users.
  - Flexible wallet: add any amount, ₹1 per 5 calls (max 10 min per pack).
  - UPI QR code payment and manual reference entry for wallet recharge.
- **User Management:**
  - Device-based login, profile setup, and onboarding.
  - Profile editing with phone verification (OTP).
- **Result Logging:**
  - AI summarizes each call and logs the result (e.g., interested, not interested, callback requested).
- **Admin Controls:**
  - API key management and user blocking via Firebase.
- **Privacy:**
  - No personal data collected; only a secure device identifier is used.
  - In-app privacy policy screen.

## Screenshots

![Logo](assets/images/logo.png)

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Firebase project (Android/iOS setup)
- Android/iOS device or emulator

### Installation
1. **Clone the repository:**
   ```sh
   git clone <your-repo-url>
   cd callai
   ```
2. **Install dependencies:**
   ```sh
   flutter pub get
   ```
3. **Configure Firebase:**
   - Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in the respective folders.
   - Update Firebase rules as needed for your use case.
4. **Run the app:**
   ```sh
   flutter run
   ```

## Usage

1. **Login/Signup:**
   - Login is device-based; no email/phone required initially.
2. **Profile Setup:**
   - Enter your name, company, and phone number (for AI agent).
3. **Agent Setup:**
   - Upload a contact list (Excel/CSV with columns: name, number, result).
   - Enter your sales pitch or call topic.
   - Refine your script with AI suggestions.
4. **Calling:**
   - Select AI quality (Normal/Medium/Best).
   - Start the calling session; AI handles the conversation.
   - Results are logged and summarized by AI.
5. **Wallet & Payment:**
   - Add money via UPI QR code.
   - ₹1 = 5 calls (max 10 min per pack).
   - Manual reference number entry for payment confirmation.

## AI Providers & Pricing
- **Normal:** DeepSeek (₹0.20/call)
- **Medium:** Gemini (₹0.60/call)
- **Best:** ChatGPT (₹1.00/call)
- Admin can enable/disable providers per user via Firebase.

## Privacy Policy
- No personal data (name, phone, email) is collected.
- Only a secure device identifier is stored in Firebase.
- See the in-app Privacy Policy screen for details.

## Testing
- Basic widget test included in `test/widget_test.dart`.

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License
This project is for demonstration and internal use. Contact the author for commercial licensing.
