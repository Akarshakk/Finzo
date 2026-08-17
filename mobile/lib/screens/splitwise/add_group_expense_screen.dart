import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/group.dart' show GroupExpenseSplit;
import '../../providers/splitwise_provider.dart';
import '../../providers/auth_provider.dart';

class AddGroupExpenseScreen extends StatefulWidget {
  final String groupId;
  final String? initialDescription;
  final double? initialAmount;
  final DateTime? initialDate;

  const AddGroupExpenseScreen({
    super.key, 
    required this.groupId,
    this.initialDescription,
    this.initialAmount,
    this.initialDate,
  });

  @override
  State<AddGroupExpenseScreen> createState() => _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState extends State<AddGroupExpenseScreen> {
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();
  String selectedCategory = 'restaurant';
  bool splitEqually = true;
  final Map<String, double> memberSplits = {};
  String? selectedPayerId;
  final Set<String> selectedMembers = {};
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<SplitWiseProvider>(context, listen: false);
    final group = provider.groups.firstWhere((g) => g.id == widget.groupId);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    selectedPayerId = authProvider.user?.id ?? group.members.first.userId;

    // Initialize from passed values
    if (widget.initialDescription != null) {
      descriptionController.text = widget.initialDescription!;
    }
    if (widget.initialAmount != null) {
      amountController.text = widget.initialAmount!.toString();
    }
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate!;
    }

    for (var member in group.members) {
      memberSplits[member.userId] = 0;
      selectedMembers.add(member.userId);
    }

    // Recalculate if amount is pre-filled
    if (widget.initialAmount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateEqualSplits());
    }
  }

  void _calculateEqualSplits() {
    final amount = double.tryParse(amountController.text) ?? 0;
    if (amount > 0 && selectedMembers.isNotEmpty) {
      final provider = Provider.of<SplitWiseProvider>(context, listen: false);
      final group = provider.groups.firstWhere((g) => g.id == widget.groupId);
      final perPerson = amount / selectedMembers.length;
      for (var member in group.members) {
        memberSplits[member.userId] = selectedMembers.contains(member.userId) ? perPerson : 0;
      }
      setState(() {});
    }
  }

  // Get sum of all member splits
  double _getSplitTotal() {
    return memberSplits.values.fold(0.0, (sum, val) => sum + val);
  }

  // Check if splits are valid (equal to total amount)
  bool _areSplitsValid() {
    final amount = double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) return false;
    if (splitEqually) return true;
    final splitTotal = _getSplitTotal();
    return (splitTotal - amount).abs() < 0.01; // Allow tiny rounding error
  }

  Future<void> _saveExpense() async {
    final provider = Provider.of<SplitWiseProvider>(context, listen: false);
    final group = provider.groups.firstWhere((g) => g.id == widget.groupId);
    
    final amount = double.tryParse(amountController.text) ?? 0;
    if (amount <= 0 || selectedPayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    // Validate unequal splits
    if (!splitEqually && !_areSplitsValid()) {
      final splitTotal = _getSplitTotal();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Split total (₹${splitTotal.toStringAsFixed(2)}) must equal expense (₹${amount.toStringAsFixed(2)})'),
          backgroundColor: FinzoTheme.error(context),
        ),
      );
      return;
    }

    // Calculate splits if equal
    if (splitEqually) {
      _calculateEqualSplits();
    }

    final payer = group.members.firstWhere((m) => m.userId == selectedPayerId);
    final splits = memberSplits.entries
        .where((e) => e.value > 0)
        .map((e) {
          final member = group.members.firstWhere((m) => m.userId == e.key);
          return GroupExpenseSplit(memberId: e.key, memberName: member.name, amount: e.value);
        }).toList();

    final success = await provider.addGroupExpense(
      groupId: widget.groupId,
      description: descriptionController.text.isEmpty ? 'Group Expense' : descriptionController.text,
      amount: amount,
      category: selectedCategory,
      paidBy: selectedPayerId!,
      paidByName: payer.name,
      splits: splits,
      date: selectedDate,
    );

    // NOTE: The backend now records each member's share as a personal expense
    // (linked via groupId + groupExpenseId). We intentionally do NOT create a
    // personal expense here anymore to avoid double counting.

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitWiseProvider>(
      builder: (context, provider, _) {
        final group = provider.groups.firstWhere((g) => g.id == widget.groupId);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUserName = authProvider.user?.name ?? 'you';
        
        // Get payer name
        String payerName = 'you';
        if (selectedPayerId != null) {
          final payer = group.members.firstWhere(
            (m) => m.userId == selectedPayerId,
            orElse: () => group.members.first,
          );
          payerName = payer.userId == authProvider.user?.id ? 'you' : payer.name;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Add expense',
              style: FinzoTypography.titleLarge(color: Colors.black),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.black),
                onPressed: _saveExpense,
              ),
            ],
          ),
          body: Container(
            color: Colors.white,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "With you and:" chip
                        Row(
                          children: [
                            Text(
                              'With ',
                              style: FinzoTypography.bodyMedium(color: Colors.black54),
                            ),
                            Text(
                              'you',
                              style: FinzoTypography.bodyMedium(color: Colors.black)
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              ' and: ',
                              style: FinzoTypography.bodyMedium(color: Colors.black54),
                            ),
                            GestureDetector(
                              onTap: () => _showMemberSelector(group),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.flight, size: 16, color: Colors.grey[700]),
                                    const SizedBox(width: 6),
                                    Text(
                                      'All of ${group.name}',
                                      style: FinzoTypography.labelMedium(color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Description field
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[100],
                              ),
                              child: Center(
                                child: Icon(Icons.receipt_long, color: Colors.grey[700], size: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: descriptionController,
                                style: FinzoTypography.bodyLarge(color: Colors.black),
                                decoration: InputDecoration(
                                  hintText: 'Enter a description',
                                  hintStyle: FinzoTypography.bodyLarge(color: Colors.grey[400]),
                                  border: InputBorder.none,
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey[700]!, width: 2),
                                  ),
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
  
                        // Date Picker
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark( // Use dark scheme for picker dialog to match theme
                                      primary: FinzoColors.brandAccent,
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1E1E1E),
                                      onSurface: Colors.white,
                                    ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1E1E1E)),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[100],
                                ),
                                child: Center(
                                  child: Icon(Icons.calendar_today, color: Colors.grey[700], size: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                                style: FinzoTypography.bodyLarge(color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Amount field
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[100],
                              ),
                              child: Center(
                                child: Text(
                                  '₹',
                                  style: FinzoTypography.titleMedium(color: Colors.grey[700]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: amountController,
                                style: FinzoTypography.displaySmall(color: Colors.black),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: FinzoTypography.displaySmall(color: Colors.grey[400]),
                                  border: InputBorder.none,
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey[700]!, width: 2),
                                  ),
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) {
                                  if (splitEqually) _calculateEqualSplits();
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Paid by / Split row
                        Row(
                          children: [
                            Text(
                              'Paid by ',
                              style: FinzoTypography.bodyMedium(color: Colors.black54),
                            ),
                            GestureDetector(
                              onTap: () => _showPayerSelector(group),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  payerName,
                                  style: FinzoTypography.labelMedium(color: Colors.black),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'and split',
                              style: FinzoTypography.bodyMedium(color: Colors.black54),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showSplitSelector(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  splitEqually ? 'equally' : 'unequally',
                                  style: FinzoTypography.labelMedium(color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Unequal split UI - show when unequal is selected
                        if (!splitEqually) ...[
                          const SizedBox(height: 24),
                          _buildUnequalSplitSection(group),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Bottom group indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.groups, color: Colors.grey[700], size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        group.name,
                        style: FinzoTypography.titleSmall(color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPayerSelector(group) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: FinzoTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Who paid?', style: FinzoTypography.titleLarge(color: FinzoTheme.textPrimary(context))),
            const SizedBox(height: 16),
            ...group.members.map<Widget>((member) {
              final isSelected = member.userId == selectedPayerId;
              final isYou = member.userId == authProvider.user?.id;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: FinzoTheme.brandAccent(context).withOpacity(0.2),
                  child: Text(member.name[0], style: TextStyle(color: FinzoTheme.brandAccent(context))),
                ),
                title: Text(
                  isYou ? '${member.name} (you)' : member.name,
                  style: FinzoTypography.bodyMedium(color: FinzoTheme.textPrimary(context)),
                ),
                trailing: isSelected ? Icon(Icons.check, color: FinzoTheme.brandAccent(context)) : null,
                onTap: () {
                  setState(() => selectedPayerId = member.userId);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showSplitSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: FinzoTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to split?', style: FinzoTypography.titleLarge(color: FinzoTheme.textPrimary(context))),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.drag_handle, color: FinzoTheme.brandAccent(context)),
              title: Text('Split equally', style: FinzoTypography.bodyMedium(color: FinzoTheme.textPrimary(context))),
              trailing: splitEqually ? Icon(Icons.check, color: FinzoTheme.brandAccent(context)) : null,
              onTap: () {
                setState(() => splitEqually = true);
                _calculateEqualSplits();
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.tune, color: FinzoTheme.brandAccent(context)),
              title: Text('Split unequally', style: FinzoTypography.bodyMedium(color: FinzoTheme.textPrimary(context))),
              trailing: !splitEqually ? Icon(Icons.check, color: FinzoTheme.brandAccent(context)) : null,
              onTap: () {
                setState(() => splitEqually = false);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberSelector(group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FinzoTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Split with', style: FinzoTypography.titleLarge(color: FinzoTheme.textPrimary(context))),
              const SizedBox(height: 16),
              ...group.members.map<Widget>((member) {
                final isSelected = selectedMembers.contains(member.userId);
                return CheckboxListTile(
                  value: isSelected,
                  activeColor: FinzoTheme.brandAccent(context),
                  title: Text(member.name, style: FinzoTypography.bodyMedium(color: FinzoTheme.textPrimary(context))),
                  subtitle: Text(member.email, style: FinzoTypography.bodySmall(color: FinzoTheme.textSecondary(context))),
                  onChanged: (val) {
                    setModalState(() {
                      if (val == true) {
                        selectedMembers.add(member.userId);
                      } else {
                        selectedMembers.remove(member.userId);
                      }
                    });
                    setState(() {
                      if (splitEqually) _calculateEqualSplits();
                    });
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: FinzoTheme.brandAccent(context)),
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnequalSplitSection(group) {
    final amount = double.tryParse(amountController.text) ?? 0;
    final splitTotal = _getSplitTotal();
    final remaining = amount - splitTotal;
    final isValid = remaining.abs() < 0.01;

    // Unequal Split Section - Light Mode Friendly
    // Unequal Split Section - Dark/Glass Theme
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isValid ? Colors.grey[300]! : FinzoColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Custom Split', style: FinzoTypography.titleSmall(color: Colors.black)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isValid ? FinzoColors.success.withOpacity(0.2) : FinzoColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isValid ? '✓ Balanced' : '₹${remaining.abs().toStringAsFixed(2)} ${remaining > 0 ? "left" : "over"}',
                  style: FinzoTypography.labelSmall(color: isValid ? const Color(0xFF4ADE80) : const Color(0xFFF87171)), // Brighter success/error for dark bg
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...group.members.where((m) => selectedMembers.contains(m.userId)).map<Widget>((member) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[200],
                    child: Text(member.name[0], style: const TextStyle(fontSize: 12, color: Colors.black)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(member.name, style: FinzoTypography.bodyMedium(color: Colors.black)),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: TextEditingController(text: memberSplits[member.userId]?.toStringAsFixed(2) ?? '0.00')
                        ..selection = TextSelection.collapsed(offset: (memberSplits[member.userId]?.toStringAsFixed(2) ?? '0.00').length),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      style: FinzoTypography.bodyMedium(color: Colors.black),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: FinzoTypography.bodyMedium(color: Colors.grey[600]),
                        hintText: '0.00',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (val) {
                         memberSplits[member.userId] = double.tryParse(val.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                         setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          Divider(color: Colors.grey[300]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: FinzoTypography.titleSmall(color: Colors.black)),
              Text(
                '₹${splitTotal.toStringAsFixed(2)} / ₹${amount.toStringAsFixed(2)}',
                style: FinzoTypography.titleSmall(color: isValid ? FinzoColors.success : FinzoColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
