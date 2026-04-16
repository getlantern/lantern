import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'report_issue_draft_notifier.g.dart';

@immutable
class ReportIssueDraftState {
  final String email;
  final String issueType;
  final String description;

  const ReportIssueDraftState({
    this.email = '',
    this.issueType = '',
    this.description = '',
  });

  ReportIssueDraftState copyWith({
    String? email,
    String? issueType,
    String? description,
  }) {
    return ReportIssueDraftState(
      email: email ?? this.email,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ReportIssueDraftState &&
        other.email == email &&
        other.issueType == issueType &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(email, issueType, description);
}

@Riverpod(keepAlive: true)
class ReportIssueDraft extends _$ReportIssueDraft {
  @override
  ReportIssueDraftState build() {
    return const ReportIssueDraftState();
  }

  void seedFromRoute({String? description, String? issueType}) {
    final nextState = state.copyWith(
      description: _seededValue(state.description, description),
      issueType: _seededValue(state.issueType, issueType),
    );

    if (nextState == state) {
      return;
    }

    state = nextState;
  }

  void setEmail(String value) {
    if (state.email == value) {
      return;
    }

    state = state.copyWith(email: value);
  }

  void setIssueType(String value) {
    if (state.issueType == value) {
      return;
    }

    state = state.copyWith(issueType: value);
  }

  void setDescription(String value) {
    if (state.description == value) {
      return;
    }

    state = state.copyWith(description: value);
  }

  void clear() {
    state = const ReportIssueDraftState();
  }

  String _seededValue(String currentValue, String? incomingValue) {
    if (currentValue.isNotEmpty) {
      return currentValue;
    }

    if (incomingValue == null || incomingValue.trim().isEmpty) {
      return currentValue;
    }

    return incomingValue;
  }
}
