import 'dart:async';
import 'package:flutter/material.dart';
import '../models/article.dart';

/// 快速模式控制器（管理快速模式的生命周期与临时稿件状态）
class QuickModeController with ChangeNotifier {
  static final QuickModeController instance = QuickModeController._internal();
  QuickModeController._internal();

  /// 当前是否处于快速模式会话中
  bool _isActive = false;
  bool get isActive => _isActive;

  /// 快速模式下的临时稿件（若已保存则记录保存后的稿件）
  Article? _tempArticle;
  Article? get tempArticle => _tempArticle;

  /// 快速模式下临时稿件是否存在未保存内容
  bool _hasUnsavedChanges = false;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// 回到编辑器的回调函数
  VoidCallback? _returnToEditorCallback;
  VoidCallback? get returnToEditorCallback => _returnToEditorCallback;

  /// 触发保存的回调函数（在未保存时调用）
  Future<bool> Function()? _saveCallback;

  /// 启动快速模式会话
  void startSession({
    required VoidCallback onReturnToEditor,
    required Future<bool> Function() onSave,
  }) {
    _isActive = true;
    _tempArticle = null;
    _hasUnsavedChanges = false;
    _returnToEditorCallback = onReturnToEditor;
    _saveCallback = onSave;
    notifyListeners();
  }

  /// 更新未保存状态
  void updateUnsavedStatus({required bool hasUnsavedChanges, Article? article}) {
    _hasUnsavedChanges = hasUnsavedChanges;
    if (article != null) {
      _tempArticle = article;
    }
    notifyListeners();
  }

  /// 回到编辑器
  void returnToEditor() {
    if (_isActive && _returnToEditorCallback != null) {
      _returnToEditorCallback!();
    }
  }

  /// 尝试通过回调保存
  Future<bool> triggerSave() async {
    if (_saveCallback != null) {
      return await _saveCallback!();
    }
    return false;
  }

  /// 退出快速模式会话
  void exitSession() {
    _isActive = false;
    _tempArticle = null;
    _hasUnsavedChanges = false;
    _returnToEditorCallback = null;
    _saveCallback = null;
    notifyListeners();
  }
}
