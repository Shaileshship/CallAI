import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/wallet_service.dart';

class WalletWidget extends StatefulWidget {
  final String deviceId;

  const WalletWidget({Key? key, required this.deviceId}) : super(key: key);

  @override
  _WalletWidgetState createState() => _WalletWidgetState();
}

class _WalletWidgetState extends State<WalletWidget> {
  double _balance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final walletData = await WalletService.getWallet(widget.deviceId);
      if (mounted) {
        setState(() {
          _balance = (walletData['walletBalance'] ?? 0.0).toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print("Error loading wallet balance: $e");
    }
  }

  Future<void> _showAddMoneyDialog() async {
    TextEditingController amountController = TextEditingController();
    TextEditingController refController = TextEditingController();
    bool paidClicked = false;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          double amount = double.tryParse(amountController.text) ?? 0.0;
          String upiUrl = 'upi://pay?pa=8368706486@ptsbi&pn=CallAI&am=${amount > 0 ? amount.toStringAsFixed(2) : ''}&cu=INR';

          return AlertDialog(
            title: Text('Add Money to Wallet', style: GoogleFonts.poppins()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (INR)'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (amount > 0 && !paidClicked) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: QrImageView(
                        data: upiUrl,
                        version: QrVersions.auto,
                        size: 180.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Scan to pay ₹$amount to 8368706486@ptsbi', textAlign: TextAlign.center),
                  ],
                  if (paidClicked) ...[
                    const SizedBox(height: 16),
                    const Text('Enter the UPI Reference Number to confirm the payment.'),
                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(hintText: 'UPI Ref No.'),
                      keyboardType: TextInputType.text,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (amount > 0 && !paidClicked)
                TextButton(
                  onPressed: () => setState(() => paidClicked = true),
                  child: const Text("I've Paid"),
                ),
              if (paidClicked)
                TextButton(
                  onPressed: () async {
                    if (refController.text.trim().isEmpty) return;
                    await WalletService.addMoney(widget.deviceId, amount, refController.text.trim());
                    await _loadWalletBalance(); // Refresh balance
                    Navigator.of(context).pop();
                  },
                  child: const Text('Submit'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showAddMoneyDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
            const SizedBox(width: 8),
            _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    '₹${_balance.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
} 