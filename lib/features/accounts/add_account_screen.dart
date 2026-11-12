import 'package:material_ui/material_ui.dart';

import '../../theme/artham_theme.dart';

import '../../data/app_database.dart';
import '../../data/repositories/account_repository.dart';

const Color arthamGreen = ArthamColors.lavender;
const Color arthamNavy = ArthamColors.text;
const Color arthamBackground = Colors.transparent;

class AddAccountScreen extends StatefulWidget {
  final AppDatabase database;
  final BankAccount? account;

  const AddAccountScreen({super.key, required this.database, this.account});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _lastFourController = TextEditingController();
  final _openingBalanceController = TextEditingController();

  late final AccountRepository _accountRepository;

  bool _isSaving = false;

  String? _selectedBank;
  DateTime _openingDate = DateTime.now();

  final List<String> _banks = [
    'Federal Bank',
    'HDFC Bank',
    'State Bank of India',
    'ICICI Bank',
    'Axis Bank',
    'South Indian Bank',
    'Canara Bank',
    'Bank of Baroda',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _accountRepository = AccountRepository(widget.database);
    final account = widget.account;
    if (account != null) {
      _selectedBank = account.bankName;
      if (!_banks.contains(account.bankName)) _banks.add(account.bankName);
      _lastFourController.text = account.accountNumberLast4 ?? '';
      _openingBalanceController.text = (account.openingBalancePaise / 100)
          .toStringAsFixed(2);
      _openingDate = account.openingDate;
    }
  }

  @override
  void dispose() {
    _lastFourController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _selectOpeningDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: arthamGreen,
              onPrimary: ArthamColors.onAccent,
              surface: ArthamColors.sheet,
              onSurface: arthamNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _openingDate = selectedDate;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _saveAccount() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedBank == null) return;

    final rupees = double.parse(_openingBalanceController.text.trim());

    final balancePaise = (rupees * 100).round();

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.account == null) {
        await _accountRepository.addAccount(
          bankName: _selectedBank!,
          accountName: legacyAccountNameForStorage(_lastFourController.text),
          accountNumberLast4: _lastFourController.text.trim(),
          openingBalancePaise: balancePaise,
          openingDate: _openingDate,
        );
      } else {
        await _accountRepository.updateAccount(
          accountId: widget.account!.id,
          bankName: _selectedBank!,
          accountName: legacyAccountNameForStorage(_lastFourController.text),
          accountNumberLast4: _lastFourController.text.trim(),
          openingBalancePaise: balancePaise,
          openingDate: _openingDate,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.account == null
                ? 'Bank account saved successfully!'
                : 'Bank account updated successfully!',
          ),
          backgroundColor: arthamGreen,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save account: $e'),
          backgroundColor: ArthamColors.debit,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: arthamNavy,
        elevation: 0,
        title: Text(
          widget.account == null ? 'Add Bank Account' : 'Edit Bank Account',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: ArthamColors.heroGradient,
                  border: ArthamColors.glassBorder,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_rounded,
                      color: Color(0xFF61D6B3),
                      size: 35,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.account == null
                                ? 'Add your account'
                                : 'Edit your account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            widget.account == null
                                ? 'Keep all your bank balances in one place.'
                                : 'Update your bank account details.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Bank details',
                style: TextStyle(
                  color: arthamNavy,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              _buildLabel('Bank name'),

              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                isExpanded: true,
                decoration: _inputDecoration(
                  hint: 'Select your bank',
                  icon: Icons.account_balance_outlined,
                ),
                items: _banks.map((bank) {
                  return DropdownMenuItem(value: bank, child: Text(bank));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBank = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a bank';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              _buildLabel('Last 4 digits of account number'),

              TextFormField(
                controller: _lastFourController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: _inputDecoration(
                  hint: 'e.g. 1234',
                  icon: Icons.credit_card_rounded,
                ).copyWith(counterText: ''),
                validator: (value) {
                  if (value == null || !RegExp(r'^\d{4}$').hasMatch(value)) {
                    return 'Enter exactly 4 digits';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              _buildLabel('Opening balance'),

              TextFormField(
                controller: _openingBalanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                decoration: _inputDecoration(
                  hint: '0.00',
                  icon: Icons.currency_rupee_rounded,
                ).copyWith(prefixText: '₹ '),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the opening balance';
                  }

                  final amount = double.tryParse(value.trim());

                  if (amount == null ||
                      !amount.isFinite ||
                      amount < 0 ||
                      amount > 999999999999) {
                    return 'Enter a valid balance';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              _buildLabel('Opening balance date'),

              InkWell(
                onTap: _selectOpeningDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 17,
                  ),
                  decoration: BoxDecoration(
                    color: ArthamColors.glass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ArthamColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: arthamGreen,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatDate(_openingDate),
                          style: const TextStyle(
                            color: arthamNavy,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: ArthamColors.muted,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: arthamGreen,
                    foregroundColor: ArthamColors.onAccent,
                    disabledBackgroundColor: arthamGreen.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ArthamColors.onAccent,
                          ),
                        )
                      else
                        Icon(
                          widget.account == null
                              ? Icons.add_rounded
                              : Icons.save_outlined,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isSaving
                            ? 'Saving...'
                            : widget.account == null
                            ? 'Save Bank Account'
                            : 'Save Changes',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Only the last four digits are requested. '
                'Never enter your PIN, CVV or internet banking password.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ArthamColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: arthamNavy,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: arthamGreen),
      filled: true,
      fillColor: ArthamColors.glass,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ArthamColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: arthamGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ArthamColors.debit),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ArthamColors.debit),
      ),
    );
  }
}
