import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/group.dart';
import '../../providers/splitwise_provider.dart';
import '../../providers/auth_provider.dart';
import 'add_group_expense_screen.dart';
import 'group_chat_screen.dart';
import '../../services/api_service.dart';
import '../../services/upi_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> with SingleTickerProviderStateMixin {
  final bool _useSimplifiedDebt = true;
  int _selectedTabIndex = 0;
  int _bottomNavIndex = 0; // 0 = Expenses, 1 = Friends, 2 = Activity
  int _touchedIndex = -1;
  
  // Tab options
  final List<String> _tabs = ['Settle up', 'Balances', 'Expenses'];

  Future<void> _scanBill() async {
    try {
      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanning receipt...')),
      );

      // Call API
      final result = await ApiService.scanBill(image);
      
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final data = result['data'];
        
        // Parse amount safely
        double? amount;
        if (data['amount'] != null) {
          if (data['amount'] is num) {
            amount = (data['amount'] as num).toDouble();
          } else if (data['amount'] is String) {
            amount = double.tryParse(data['amount'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
          }
        }

        // Parse date
        DateTime? date;
        if (data['date'] != null && data['date'] != 'Not Mentioned') {
          try {
            date = DateTime.parse(data['date']);
          } catch (e) {
            print('Date parse error: $e');
          }
        }

        // Navigate to add expense with data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddGroupExpenseScreen(
              groupId: widget.groupId,
              initialDescription: data['merchant'] != "Not Avl" ? data['merchant'] : null,
              initialAmount: amount,
              initialDate: date,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['message'] ?? 'Failed to scan receipt')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitWiseProvider>(
      builder: (context, provider, _) {
        final group = provider.groups.firstWhere(
          (g) => g.id == widget.groupId,
          orElse: () => Group(
            id: '', name: '', description: '', members: [], expenses: [],
            createdAt: DateTime.now(), createdBy: '', imageUrl: '', inviteCode: '',
          ),
        );

        if (group.id.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Group Details')),
            body: const Center(child: Text('Group not found')),
          );
        }

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.user?.id ?? '';
        GroupMember? userMember;
        if (group.members.isNotEmpty) {
          userMember = group.members.firstWhere(
            (m) => m.userId == userId,
            orElse: () => group.members.first,
          );
        }
        final userBalance = userMember?.balance ?? 0.0;

        // Custom "Hybrid" Theme: Dark Header, Light Body
        // We use FinzoColors.background (Light) for the scaffold
        return Scaffold(
          backgroundColor: FinzoColors.background, 
          body: SafeArea(
            child: Column(
              children: [
                // Header Section (Always Dark)
                _buildHeader(context, group, userBalance),
                
                // Content Area (Light Body)
                Expanded(
                  child: _buildTabContent(context, group),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(context, group),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Scan Button
              Container(
                margin: const EdgeInsets.only(bottom: 16, right: 4),
                child: FloatingActionButton.extended(
                  heroTag: 'scan_fab',
                  onPressed: _scanBill,
                  backgroundColor: FinzoColors.surfaceVariant,
                  label: Text('Scan', style: FinzoTypography.labelMedium(color: FinzoColors.textPrimary)),
                  icon: const Icon(Icons.camera_alt_outlined, color: FinzoColors.textPrimary),
                ),
              ),
              
              // Add Expense Button
              SizedBox(
                width: 180,
                child: FloatingActionButton.extended(
                  heroTag: 'add_expense_fab',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddGroupExpenseScreen(groupId: widget.groupId),
                      ),
                    );
                  },
                  backgroundColor: FinzoColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  label: const Text('Add expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  icon: const Icon(Icons.receipt_long, color: Colors.white),
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Group group, double userBalance) {
    // Live Debt Calculation
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myId = authProvider.user?.id;
    
    // Filter other members with non-zero balance
    final relevantMembers = group.members
        .where((m) => m.userId != myId && m.balance.abs() > 0.1)
        .toList();
    
    // Sort by largest debt first
    relevantMembers.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FinzoColors.darkToGoldGradient,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.settings_outlined, size: 20, color: Colors.white),
                ),
                onPressed: () => _showGroupSettings(group),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Group Name
          Text(
            group.name,
            style: FinzoTypography.displayMedium(color: Colors.white),
          ),
          
          const SizedBox(height: 12),
          
          // Info Chips
          Row(
            children: [
              _buildTransparentChip(
                Icons.calendar_today, 
                _getDateRangeString(group),
              ),
              const SizedBox(width: 8),
              _buildTransparentChip(Icons.people, '${group.members.length} people'),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Balance Status - "You are owed"
          Text(
            userBalance.abs() < 0.1
                ? 'You are settled up'
                : userBalance > 0
                    ? 'You are owed ₹${userBalance.toStringAsFixed(2)} overall'
                    : 'You owe ₹${userBalance.abs().toStringAsFixed(2)} overall',
            style: FinzoTypography.titleLarge(color: Colors.white),
          ),
          
          const SizedBox(height: 8),
          
          // Live Debt Details
          if (relevantMembers.isNotEmpty) ...[
            ...relevantMembers.take(2).map((member) {
              final isOwedByMe = member.balance > 0; // If they are +, they lent more -> I owe them?
              // Wait, let's recheck logic logic:
              // GroupMember.balance = lent - owed.
              // If MyBalance > 0 (I lent more), I am owed.
              // Who owes me? People with Balance < 0.
              
              // If MyBalance < 0 (I borrowed more), I owe.
              // Who do I owe? People with Balance > 0.
              
              // If userBalance > 0: Show members with balance < 0.
              // Text: "MEMBER owes you".
              
              // If userBalance < 0: Show members with balance > 0.
              // Text: "You owe MEMBER".

              if (userBalance > 0 && member.balance < 0) {
                 return _buildDebtLine(member.name, member.balance.abs(), true);
              } else if (userBalance < 0 && member.balance > 0) {
                 return _buildDebtLine(member.name, userBalance.abs() < member.balance ? userBalance.abs() : member.balance, false);
                 // Note: The exact amount "I owe X" is fuzzy in net balances. 
                 // Simple view: Just show "You owe X" and X's full positive balance or my full negative balance? 
                 // Standard Splitwise: "You owe X ₹123".
                 // Heuristic: If I owe, list the top creditors. 
              }
              return const SizedBox.shrink(); 
            }),
             
            if (relevantMembers.length > 2)
              Text(
                'Plus ${relevantMembers.length - 2} other balances',
                style: FinzoTypography.bodyMedium(color: Colors.white.withOpacity(0.7)),
              ),
          ],
          
          const SizedBox(height: 24),

          // Action Buttons Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionButton(
                  'Settle up', 
                  FinzoTheme.brandAccent(context), 
                  Colors.white,
                  () => setState(() => _selectedTabIndex = 0)
                ),
                const SizedBox(width: 12),

                _buildActionButton(
                  'Balances', 
                  Colors.white.withOpacity(0.1), 
                  Colors.white,
                  () => setState(() => _selectedTabIndex = 1)
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  'Total', 
                  Colors.white.withOpacity(0.1), 
                  Colors.white,
                  () => setState(() => _selectedTabIndex = 3), // Show Total Tab
                  icon: Icons.pie_chart
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  'Chat', 
                  Colors.white.withOpacity(0.1), 
                  Colors.white,
                  () {
                    final group = Provider.of<SplitWiseProvider>(context, listen: false)
                        .groups.firstWhere((g) => g.id == widget.groupId);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupChatScreen(
                          groupId: widget.groupId,
                          groupName: group.name,
                        ),
                      ),
                    );
                  },
                  icon: Icons.chat_bubble
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransparentChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: FinzoTypography.labelMedium(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtLine(String name, double amount, bool isOwed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: FinzoTypography.bodyMedium(color: Colors.white.withOpacity(0.9)),
          children: [
            TextSpan(text: '$name ${isOwed ? "owes you" : "you owe"} '),
            TextSpan(
              text: '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isOwed ? FinzoTheme.success(context) : FinzoTheme.error(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color bgColor, Color textColor, VoidCallback onTap, {IconData? icon}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: FinzoTypography.labelMedium(color: textColor).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FinzoTheme.surfaceVariant(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FinzoTheme.textSecondary(context)),
          const SizedBox(width: 6),
          Text(label, style: FinzoTypography.labelSmall(color: FinzoTheme.textSecondary(context))),
        ],
      ),
    );
  }



  Widget _buildTabContent(BuildContext context, Group group) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildSettlementsTab(context, group);
      case 1:
        return _buildBalancesTab(context, group);
      case 2:
        return _buildExpensesTab(context, group);
      case 3:
        return _buildTotalTab(context, group);
      case 4:
        return _buildSimplifiedFriendsTab(context, group);
      default:
        return _buildExpensesTab(context, group);
    }
  }

  Widget _buildSettlementsTab(BuildContext context, Group group) {
    final settlements = _calculateSettlements(group);
    
    if (settlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: FinzoTheme.brandAccent(context)),
            const SizedBox(height: 16),
            Text('You are all settled up', style: FinzoTypography.titleLarge(color: FinzoTheme.textPrimary(context))),
            const SizedBox(height: 8),
            Text('Tap to show settled expenses', style: FinzoTypography.bodySmall(color: FinzoTheme.textSecondary(context))),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: settlements.length,
      itemBuilder: (context, index) {
        final settlement = settlements[index];
        return _buildSettlementCard(context, group, settlement);
      },
    );
  }

  Widget _buildSettlementCard(BuildContext context, Group group, Map<String, dynamic> settlement) {
    final amount = (settlement['amount'] as num).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FinzoTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FinzoTheme.brandAccent(context).withOpacity(0.25)),
        boxShadow: FinzoShadows.small,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FinzoTheme.brandAccent(context).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.swap_horiz, color: FinzoTheme.brandAccent(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${settlement['from']} → ${settlement['to']}',
                      style: FinzoTypography.titleSmall(color: FinzoTheme.textPrimary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${settlement['from']} owes ${settlement['to']}',
                      style: FinzoTypography.bodySmall(color: FinzoTheme.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: FinzoTypography.headlineMedium(color: FinzoTheme.brandAccent(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSettleDialog(context, group, settlement),
              style: ElevatedButton.styleFrom(
                backgroundColor: FinzoTheme.brandAccent(context),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              label: const Text('Settle up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancesTab(BuildContext context, Group group) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: group.members.length,
      itemBuilder: (context, index) {
        final member = group.members[index];
        final balance = member.balance;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FinzoTheme.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FinzoTheme.divider(context)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: FinzoTheme.brandAccent(context).withOpacity(0.2),
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: TextStyle(color: FinzoTheme.brandAccent(context)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: FinzoTypography.titleSmall(color: FinzoTheme.textPrimary(context))),
                    Text(member.email, style: FinzoTypography.bodySmall(color: FinzoTheme.textSecondary(context))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balance >= 0 ? 'Gets back' : 'Owes',
                    style: FinzoTypography.labelSmall(color: FinzoTheme.textSecondary(context)),
                  ),
                  Text(
                    '₹${balance.abs().toStringAsFixed(0)}',
                    style: FinzoTypography.titleMedium(
                      color: balance >= 0 ? FinzoTheme.success(context) : FinzoTheme.error(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpensesTab(BuildContext context, Group group) {
    if (group.expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: FinzoTheme.textSecondary(context)),
            const SizedBox(height: 16),
            Text('No expenses yet', style: FinzoTypography.titleMedium(color: FinzoTheme.textSecondary(context))),
            const SizedBox(height: 8),
            Text('Add your first expense', style: FinzoTypography.bodySmall(color: FinzoTheme.textTertiary(context))),
          ],
        ),
      );
    }

    // Sort by date descending
    final sortedExpenses = List<GroupExpense>.from(group.expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Group expenses under a "Month Year" header.
    final List<Widget> children = [];
    String? lastMonthKey;
    for (final expense in sortedExpenses) {
      final monthKey = '${_getMonthName(expense.date.month)} ${expense.date.year}';
      if (monthKey != lastMonthKey) {
        children.add(Padding(
          padding: EdgeInsets.only(top: lastMonthKey == null ? 0 : 12, bottom: 12),
          child: Text(
            monthKey,
            style: FinzoTypography.titleSmall(color: FinzoTheme.textSecondary(context)),
          ),
        ));
        lastMonthKey = monthKey;
      }
      children.add(_buildExpenseItem(context, expense));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...children,
        const SizedBox(height: 90), // Padding for FAB
      ],
    );
  }

  Widget _buildExpenseItem(BuildContext context, GroupExpense expense) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myId = authProvider.user?.id ?? '';

    // Compute the current user's real position on this expense.
    final myShare = expense.splits
        .where((s) => s.memberId == myId)
        .fold<double>(0, (sum, s) => sum + s.amount);
    final bool iPaid = expense.paidBy == myId;
    // If I paid, I lent the total minus my own share. Otherwise I owe my share.
    final double net = iPaid ? (expense.amount - myShare) : -myShare;

    final String tagLabel = net > 0.01
        ? 'you lent'
        : net < -0.01
            ? 'you borrowed'
            : 'not involved';
    final Color tagColor = net > 0.01
        ? FinzoTheme.success(context)
        : net < -0.01
            ? FinzoTheme.error(context)
            : FinzoTheme.textTertiary(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FinzoTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FinzoTheme.divider(context)),
        boxShadow: FinzoShadows.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date Column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Text(
                  _getMonthName(expense.date.month).substring(0, 3),
                  style: FinzoTypography.labelSmall(color: FinzoTheme.textSecondary(context)),
                ),
                Text(
                  '${expense.date.day}',
                  style: FinzoTypography.titleLarge(color: FinzoTheme.textPrimary(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FinzoTheme.brandAccent(context).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getCategoryIcon(expense.category), color: FinzoTheme.brandAccent(context), size: 20),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FinzoTypography.titleMedium(color: FinzoTheme.textPrimary(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${iPaid ? "You" : expense.paidByName} paid ₹${expense.amount.toStringAsFixed(2)}',
                  style: FinzoTypography.bodySmall(color: FinzoTheme.textSecondary(context)),
                ),
              ],
            ),
          ),

          // Lending Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tagLabel, style: FinzoTypography.labelSmall(color: tagColor)),
              if (net.abs() > 0.01)
                Text(
                  '₹${net.abs().toStringAsFixed(2)}',
                  style: FinzoTypography.titleSmall(color: tagColor).copyWith(fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Scan Button
          Container(
            decoration: BoxDecoration(
              color: FinzoTheme.surfaceVariant(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _scanBill,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt_outlined, color: FinzoTheme.textSecondary(context)),
                      const SizedBox(width: 8),
                      Text('Scan', style: FinzoTypography.labelMedium(color: FinzoTheme.textSecondary(context))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Add Expense Button
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [FinzoColors.brandPrimary, FinzoColors.brandSecondary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddGroupExpenseScreen(groupId: widget.groupId),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Add expense', style: FinzoTypography.labelLarge(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, Group group) {
    final items = [
      {'icon': Icons.groups_outlined, 'activeIcon': Icons.groups, 'label': 'Group'},
      {'icon': Icons.person_outline, 'activeIcon': Icons.person, 'label': 'Friends'},
      {'icon': Icons.history_outlined, 'activeIcon': Icons.history, 'label': 'Activity'},
    ];
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: FinzoTheme.surface(context),
        border: Border(top: BorderSide(color: FinzoTheme.divider(context))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isSelected = _bottomNavIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() => _bottomNavIndex = index);
              if (index == 0) {
                 setState(() => _selectedTabIndex = 2); // Group -> Expenses
              } else if (index == 1) {
                setState(() => _selectedTabIndex = 4); // Friends Tab
              } else if (index == 2) {
                setState(() => _selectedTabIndex = 0); // Activity -> Settlements (Settle up)
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? items[index]['activeIcon'] as IconData : items[index]['icon'] as IconData,
                  color: isSelected ? FinzoTheme.brandAccent(context) : FinzoTheme.textSecondary(context),
                ),
                const SizedBox(height: 4),
                Text(
                  items[index]['label'] as String,
                  style: FinzoTypography.labelSmall(
                    color: isSelected ? FinzoTheme.brandAccent(context) : FinzoTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showGroupSettings(Group group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FinzoTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share, color: FinzoTheme.brandAccent(context)),
              title: Text('Share Invite Code', style: FinzoTypography.titleSmall(color: FinzoTheme.textPrimary(context))),
              subtitle: Text('Code: ${group.inviteCode}', style: FinzoTypography.bodySmall(color: FinzoTheme.textSecondary(context))),
              onTap: () {
                Clipboard.setData(ClipboardData(text: group.inviteCode));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person_add, color: FinzoTheme.brandAccent(context)),
              title: Text('Add Member', style: FinzoTypography.titleSmall(color: FinzoTheme.textPrimary(context))),
              onTap: () {
                Navigator.pop(context);
                _showAddMemberDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: FinzoColors.error),
              title: Text('Leave Group', style: FinzoTypography.titleSmall(color: FinzoColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showLeaveGroupDialog(group);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettleDialog(BuildContext context, Group group, Map<String, dynamic> settlement) {
    final double amount = (settlement['amount'] as num).toDouble();
    final GroupMember payee = group.members.firstWhere(
      (m) => m.userId == settlement['toId'],
      orElse: () => group.members.first,
    );
    final upiController = TextEditingController(text: payee.upiId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Settle up', style: FinzoTypography.titleLarge(color: FinzoTheme.textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FinzoTheme.brandAccent(context).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FinzoTheme.brandAccent(context).withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  Text('You pay', style: FinzoTypography.labelMedium(color: FinzoTheme.textSecondary(context))),
                  const SizedBox(height: 4),
                  Text('₹${amount.toStringAsFixed(2)}',
                      style: FinzoTypography.displaySmall(color: FinzoTheme.brandAccent(context))
                          .copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('to ${settlement['to']}',
                      style: FinzoTypography.bodyMedium(color: FinzoTheme.textPrimary(context))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text("${settlement['to']}'s UPI ID",
                style: FinzoTypography.labelMedium(color: FinzoTheme.textSecondary(context))),
            const SizedBox(height: 6),
            TextField(
              controller: upiController,
              autocorrect: false,
              style: FinzoTypography.bodyMedium(color: FinzoTheme.textPrimary(context)),
              decoration: InputDecoration(
                hintText: 'name@bank',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Pay now" to choose a UPI app (GPay, PhonePe, Paytm...). '
              'After paying, confirm to mark this settled.',
              style: FinzoTypography.bodySmall(color: FinzoTheme.textTertiary(context)),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: FinzoTheme.textSecondary(context))),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _markSettled(group, settlement);
                },
                child: const Text('Mark settled', style: TextStyle(color: Colors.green)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () async {
                  final upiId = upiController.text.trim();
                  if (!UpiService.isValidUpiId(upiId)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid UPI ID (e.g. name@bank)'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await _payViaUpi(group, settlement, upiId, payee.name);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinzoTheme.brandAccent(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.qr_code_2, color: Colors.white, size: 18),
                label: const Text('Pay now', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Directly marks a settlement as paid (e.g. cash / already paid).
  Future<void> _markSettled(Group group, Map<String, dynamic> settlement) async {
    final provider = Provider.of<SplitWiseProvider>(context, listen: false);
    final success = await provider.settleUp(
      groupId: group.id,
      fromUserId: settlement['fromId'],
      toUserId: settlement['toId'],
      amount: (settlement['amount'] as num).toDouble(),
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settled!'), backgroundColor: Colors.green),
      );
      await provider.fetchGroupById(group.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Could not settle'), backgroundColor: Colors.red),
      );
    }
  }

  /// Opens a UPI app for payment, then asks the user to confirm settlement.
  Future<void> _payViaUpi(
    Group group,
    Map<String, dynamic> settlement,
    String upiId,
    String payeeName,
  ) async {
    final amount = (settlement['amount'] as num).toDouble();
    final launched = await UpiService.payViaUpi(
      payeeUpiId: upiId,
      payeeName: payeeName,
      amount: amount,
      note: 'Finzo · ${group.name}',
    );

    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI app found. Install GPay/PhonePe/Paytm or use "Mark settled".'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // After returning from the UPI app, confirm whether the payment went through.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Payment complete?', style: FinzoTypography.titleLarge(color: FinzoTheme.textPrimary(context))),
        content: Text(
          'Did you successfully pay ₹${amount.toStringAsFixed(2)} to $payeeName?',
          style: FinzoTypography.bodyMedium(color: FinzoTheme.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not yet', style: TextStyle(color: FinzoTheme.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _markSettled(group, settlement);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, mark settled', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        title: Text('Add Member', style: FinzoTypography.titleLarge(color: FinzoTheme.textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                final provider = Provider.of<SplitWiseProvider>(context, listen: false);
                provider.addMemberToGroup(
                  groupId: widget.groupId,
                  userId: 'user_${emailController.text.split('@')[0]}',
                  name: nameController.text,
                  email: emailController.text,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added!')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog(Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final provider = Provider.of<SplitWiseProvider>(context, listen: false);
              final success = await provider.leaveGroup(group.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left group')));
                }
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _calculateSettlements(Group group) {
    Map<String, double> balances = {};
    for (var member in group.members) {
      balances[member.userId] = member.balance;
    }

    List<MapEntry<String, double>> creditors = [];
    List<MapEntry<String, double>> debtors = [];

    balances.forEach((userId, balance) {
      if (balance > 0.01) {
        creditors.add(MapEntry(userId, balance));
      } else if (balance < -0.01) {
        debtors.add(MapEntry(userId, -balance));
      }
    });

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> settlements = [];
    int ci = 0, di = 0;

    while (ci < creditors.length && di < debtors.length) {
      var creditor = creditors[ci];
      var debtor = debtors[di];
      double amount = creditor.value < debtor.value ? creditor.value : debtor.value;

      final debtorMember = group.members.firstWhere((m) => m.userId == debtor.key);
      final creditorMember = group.members.firstWhere((m) => m.userId == creditor.key);

      settlements.add({
        'from': debtorMember.name,
        'fromId': debtor.key,
        'to': creditorMember.name,
        'toId': creditor.key,
        'amount': amount,
      });

      creditors[ci] = MapEntry(creditor.key, creditor.value - amount);
      debtors[di] = MapEntry(debtor.key, debtor.value - amount);

      if (creditors[ci].value < 0.01) ci++;
      if (debtors[di].value < 0.01) di++;
    }

    return settlements;
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'restaurant':
      case 'food':
        return Icons.restaurant;
      case 'transportation':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'utilities':
        return Icons.lightbulb;
      case 'local_bar':
        return Icons.local_bar;
      default:
        return Icons.receipt;
    }
  }

  String _getDateRangeString(Group group) {
    if (group.expenses.isEmpty) {
      final now = DateTime.now();
      return _formatMonthDay(now);
    }

    DateTime minDate = group.expenses.first.date;
    DateTime maxDate = group.expenses.first.date;

    for (var expense in group.expenses) {
      if (expense.date.isBefore(minDate)) minDate = expense.date;
      if (expense.date.isAfter(maxDate)) maxDate = expense.date;
    }

    if (minDate.year == maxDate.year && minDate.month == maxDate.month && minDate.day == maxDate.day) {
      return _formatMonthDay(minDate);
    } else if (minDate.month == maxDate.month && minDate.year == maxDate.year) {
      return '${_getMonthName(minDate.month)} ${minDate.day} - ${maxDate.day}';
    } else {
      return '${_formatMonthDay(minDate)} - ${_formatMonthDay(maxDate)}';
    }
  }

  Widget _buildSimplifiedFriendsTab(BuildContext context, Group group) {
    if (group.members.isEmpty) {
      return const Center(child: Text("No members yet"));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: group.members.length,
      itemBuilder: (context, index) {
        final member = group.members[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FinzoTheme.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FinzoTheme.divider(context)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: FinzoTheme.brandAccent(context).withOpacity(0.2),
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: TextStyle(color: FinzoTheme.brandAccent(context)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: FinzoTypography.titleSmall(color: FinzoTheme.textPrimary(context))),
                    if (member.email.isNotEmpty)
                      Text(member.email, style: FinzoTypography.bodySmall(color: FinzoTheme.textSecondary(context))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalTab(BuildContext context, Group group) {
    if (group.expenses.isEmpty) {
      return const Center(child: Text("No expenses yet to show total"));
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? '';

    double totalGroupExpense = 0;
    double myExpense = 0;

    for (var expense in group.expenses) {
      totalGroupExpense += expense.amount;
      final mySplit = expense.splits.firstWhere(
        (s) => s.memberId == userId,
        orElse: () => GroupExpenseSplit(memberId: '', memberName: '', amount: 0),
      );
      myExpense += mySplit.amount;
    }

    double othersExpense = totalGroupExpense - myExpense;
    
    if (totalGroupExpense == 0) {
       return const Center(child: Text("Total expense is 0"));
    }

    // Donut Chart Data
    List<PieChartSectionData> sections = [];
    
    // My Share Section
    final isMyTouched = _touchedIndex == 0;
    final myRadius = isMyTouched ? 28.0 : 22.0;
    
    if (myExpense > 0) {
      sections.add(
        PieChartSectionData(
          color: FinzoTheme.brandAccent(context),
          value: myExpense,
          title: '', 
          radius: myRadius,
          showTitle: false,
        ),
      );
    }

    // Others Share Section
    final isOthersTouched = _touchedIndex == 1;
    final othersRadius = isOthersTouched ? 28.0 : 22.0;

    if (othersExpense > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.grey.shade300, 
          value: othersExpense,
          title: '',
          radius: othersRadius,
          showTitle: false,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Donut Chart with Center Text
          Center(
            child: SizedBox(
              height: 250,
              width: 250,
              child: Stack(
                children: [
                  // Shadow for 3D depth
                  Center(
                    child: Container(
                      height: 210, 
                      width: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                           BoxShadow(
                             color: Colors.black.withOpacity(0.05),
                             blurRadius: 20,
                             offset: const Offset(0, 10),
                           ),
                        ],
                      ),
                    ),
                  ),
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 2, // Slight gap for better 3D look
                      centerSpaceRadius: 90, 
                      startDegreeOffset: 270, 
                      sections: sections,
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: FinzoTypography.bodyMedium(color: FinzoTheme.textSecondary(context)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalGroupExpense.toStringAsFixed(2)}',
                          style: FinzoTypography.headlineMedium(color: FinzoTheme.textPrimary(context)).copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Vertical Stats List
          _buildStatItem(
            context,
            label: 'Total spent',
            amount: totalGroupExpense,
            color: FinzoTheme.textPrimary(context), 
            pillColor: Colors.grey.shade400, 
          ),
          const SizedBox(height: 24),
          _buildStatItem(
            context,
            label: 'Your share',
            amount: myExpense,
            color: FinzoTheme.brandAccent(context),
            pillColor: FinzoTheme.brandAccent(context),
            subLabel: '${((myExpense / totalGroupExpense) * 100).toStringAsFixed(0)}% of total group spending',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, {
    required String label, 
    required double amount, 
    required Color color, 
    required Color pillColor,
    String? subLabel
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vertical Pill Icon
        Container(
          width: 6,
          height: 24, // Approximation of pill height relative to text
          margin: const EdgeInsets.only(top: 6, right: 16), // Align with text top
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: FinzoTypography.bodyMedium(color: FinzoTheme.textSecondary(context)),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.help_outline, size: 14, color: FinzoTheme.textSecondary(context)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: FinzoTypography.displaySmall(color: color), // Large amount text
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  subLabel,
                  style: FinzoTypography.bodySmall(color: FinzoTheme.textSecondary(context)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatMonthDay(DateTime date) {
    return '${_getMonthName(date.month)} ${date.day}';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
