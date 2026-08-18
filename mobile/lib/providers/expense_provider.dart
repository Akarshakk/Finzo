import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  List<Expense> _latestExpenses = [];
  bool _isLoading = false;
  String? _errorMessage;
  double _totalExpense = 0;
  int _totalCount = 0;

  List<Expense> get expenses => _expenses;
  List<Expense> get latestExpenses => _latestExpenses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get totalExpense => _totalExpense;
  int get totalCount => _totalCount;

  // Fetch all expenses
  Future<void> fetchExpenses({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? page,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Map<String, String> queryParams = {};
      if (category != null) queryParams['category'] = category;
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (limit != null) queryParams['limit'] = limit.toString();
      if (page != null) queryParams['page'] = page.toString();

      final response = await ApiService.get(
        ApiConstants.expenses,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response['success'] == true) {
        final List<dynamic> expenseList = response['data']['expenses'] ?? [];
        _expenses = expenseList.map((e) => Expense.fromJson(e)).toList();
        _totalExpense = (response['totalAmount'] ?? 0).toDouble();
        _totalCount = response['total'] ?? 0;
      } else {
        _errorMessage = response['message'] ?? 'Failed to fetch expenses';
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fetch latest 10 expenses
  Future<void> fetchLatestExpenses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.get(ApiConstants.latestExpenses);

      if (response['success'] == true) {
        final List<dynamic> expenseList = response['data']['expenses'] ?? [];
        _latestExpenses = expenseList.map((e) => Expense.fromJson(e)).toList();
      } else {
        _errorMessage = response['message'] ?? 'Failed to fetch latest expenses';
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Add expense
  Future<bool> addExpense({
    required double amount,
    required String category,
    String? description,
    String? merchant,
    DateTime? date,
    String? groupExpenseId,
    String? groupId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        ApiConstants.expenses,
        body: {
          'amount': amount,
          'category': category,
          'description': description ?? '',
          'merchant': merchant ?? '',
          'date': (date ?? DateTime.now()).toIso8601String(),
          if (groupExpenseId != null) 'groupExpenseId': groupExpenseId,
          if (groupId != null) 'groupId': groupId,
        },
      );

      if (response['success'] == true) {
        final newExpense = Expense.fromJson(response['data']['expense']);
        _expenses.insert(0, newExpense);
        _latestExpenses.insert(0, newExpense);
        if (_latestExpenses.length > 10) {
          _latestExpenses.removeLast();
        }
        _totalExpense += amount;
        _totalCount++;
        _isLoading = false;
        notifyListeners();
        // Notify only for direct personal expenses (group expenses are created
        // on the backend and would otherwise double-notify).
        if (groupId == null) {
          NotificationService().showExpenseAdded(amount: amount, category: category);
        }
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to add expense';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update expense
  Future<bool> updateExpense({
    required String id,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
  }) async {
    try {
      Map<String, dynamic> body = {};
      if (amount != null) body['amount'] = amount;
      if (category != null) body['category'] = category;
      if (description != null) body['description'] = description;
      if (date != null) body['date'] = date.toIso8601String();

      final response = await ApiService.put(
        '${ApiConstants.expenses}/$id',
        body: body,
      );

      if (response['success'] == true) {
        // Refresh expenses after update
        await fetchExpenses();
        await fetchLatestExpenses();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to update expense';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Delete expense
  Future<bool> deleteExpense(String id) async {
    try {
      final response = await ApiService.delete('${ApiConstants.expenses}/$id');

      if (response['success'] == true) {
        // Remove from local lists immediately for UI responsiveness
        _expenses.removeWhere((e) => e.id == id);
        _latestExpenses.removeWhere((e) => e.id == id);
        notifyListeners();
        
        // Refresh all data to update dashboard charts and balances
        await fetchExpenses();
        await fetchLatestExpenses();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to delete expense';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Delete expense by group link (for when group expense is deleted)
  Future<bool> deleteExpenseByGroupLink(String groupId, String groupExpenseId) async {
    try {
      final response = await ApiService.delete(
        '${ApiConstants.expenses}/by-group/$groupId/$groupExpenseId'
      );

      if (response['success'] == true) {
        // Refresh all data to update UI
        await fetchExpenses();
        await fetchLatestExpenses();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to delete linked expense';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Check for duplicate expenses
  Future<Map<String, dynamic>> checkDuplicate({
    required double amount,
    required String category,
    DateTime? date,
    String? merchant,
  }) async {
    try {
      final response = await ApiService.post(
        ApiConstants.checkDuplicate,
        body: {
          'amount': amount,
          'category': category,
          'date': (date ?? DateTime.now()).toIso8601String(),
          'merchant': merchant ?? '',
        },
      );

      return {
        'success': response['success'] ?? false,
        'isDuplicate': response['isDuplicate'] ?? false,
        'message': response['message'] ?? '',
        'duplicates': response['duplicates'] ?? [],
      };
    } catch (e) {
      return {
        'success': false,
        'isDuplicate': false,
        'message': e.toString(),
        'duplicates': [],
      };
    }
  }

  // Clear data
  void clear() {
    _expenses = [];
    _latestExpenses = [];
    _totalExpense = 0;
    _totalCount = 0;
    _errorMessage = null;
    notifyListeners();
  }
}


