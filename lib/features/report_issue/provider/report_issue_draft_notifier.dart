import 'package:flutter/foundation.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'report_issue_draft_notifier.g.dart';

@immutable
class ReportIssueDraftState {
  static const Object _unset = Object();

  final String email;
  final String issueType;
  final String description;
  final List<ReportIssueAttachment> attachments;
  final String? attachmentError;

  const ReportIssueDraftState({
    this.email = '',
    this.issueType = '',
    this.description = '',
    this.attachments = const <ReportIssueAttachment>[],
    this.attachmentError,
  });

  int get totalAttachmentBytes =>
      ReportIssueAttachmentRulesUtils.totalBytes(attachments);

  ReportIssueDraftState copyWith({
    String? email,
    String? issueType,
    String? description,
    List<ReportIssueAttachment>? attachments,
    Object? attachmentError = _unset,
  }) {
    return ReportIssueDraftState(
      email: email ?? this.email,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      attachments: attachments ?? this.attachments,
      attachmentError: identical(attachmentError, _unset)
          ? this.attachmentError
          : attachmentError as String?,
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
        other.description == description &&
        other.attachmentError == attachmentError &&
        listEquals(other.attachments, attachments);
  }

  @override
  int get hashCode => Object.hash(
    email,
    issueType,
    description,
    attachmentError,
    Object.hashAll(attachments),
  );
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

  void addAttachments(
    Iterable<ReportIssueAttachment> attachments, {
    int reservedBytes = 0,
  }) {
    final incoming = attachments.toList(growable: false);
    if (incoming.isEmpty) {
      return;
    }

    final knownPaths = state.attachments
        .map((attachment) => attachment.path)
        .toSet();
    final nextAttachments = List<ReportIssueAttachment>.of(state.attachments);

    for (final attachment in incoming) {
      if (knownPaths.add(attachment.path)) {
        nextAttachments.add(attachment);
      }
    }

    if (nextAttachments.length == state.attachments.length) {
      state = state.copyWith(
        attachmentError:
            ReportIssueAttachmentRulesUtils.duplicateAttachmentMessage,
      );
      return;
    }

    final validationError = ReportIssueAttachmentRulesUtils.validateAttachments(
      nextAttachments,
      reservedBytes: reservedBytes,
    );
    if (validationError != null) {
      state = state.copyWith(attachmentError: validationError);
      return;
    }

    state = state.copyWith(
      attachments: List<ReportIssueAttachment>.unmodifiable(nextAttachments),
      attachmentError: null,
    );
  }

  void removeAttachment(ReportIssueAttachment attachment) {
    final nextAttachments = state.attachments
        .where((item) => item.path != attachment.path)
        .toList(growable: false);
    if (listEquals(nextAttachments, state.attachments)) {
      return;
    }

    state = state.copyWith(
      attachments: List<ReportIssueAttachment>.unmodifiable(nextAttachments),
      attachmentError: null,
    );
  }

  void setAttachmentError(String? message) {
    if (state.attachmentError == message) {
      return;
    }

    state = state.copyWith(attachmentError: message);
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
