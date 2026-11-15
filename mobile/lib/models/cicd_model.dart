/// CI/CD & GitHub Data Models
/// Based on Thilina's (M7) Backend API Handoff Specification (10 Nov 2026)
/// Used by S13, S14, S15, S24 screens
library;

class GithubRepoModel {
  final String fullName;
  final String owner;
  final String name;
  final String? description;
  final String defaultBranch;
  final bool isPrivate;
  final String htmlUrl;
  final int openIssuesCount;
  final DateTime? pushedAt;
  final DateTime? updatedAt;

  GithubRepoModel({
    required this.fullName,
    required this.owner,
    required this.name,
    this.description,
    this.defaultBranch = 'main',
    this.isPrivate = true,
    required this.htmlUrl,
    this.openIssuesCount = 0,
    this.pushedAt,
    this.updatedAt,
  });

  factory GithubRepoModel.fromJson(Map<String, dynamic> json) {
    return GithubRepoModel(
      fullName: json['full_name'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      defaultBranch: json['default_branch'] as String? ?? 'main',
      isPrivate: json['private'] as bool? ?? true,
      htmlUrl: json['html_url'] as String? ?? '',
      openIssuesCount: json['open_issues_count'] as int? ?? 0,
      pushedAt: json['pushed_at'] != null ? DateTime.tryParse(json['pushed_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'owner': owner,
    'name': name,
    'description': description,
    'default_branch': defaultBranch,
    'private': isPrivate,
    'html_url': htmlUrl,
    'open_issues_count': openIssuesCount,
    'pushed_at': pushedAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

class GitCommitModel {
  final String sha;
  final String shortSha;
  final String title;
  final String message;
  final String authorName;
  final String authorLogin;
  final DateTime? authoredAt;
  final String htmlUrl;

  GitCommitModel({
    required this.sha,
    required this.shortSha,
    required this.title,
    required this.message,
    required this.authorName,
    required this.authorLogin,
    this.authoredAt,
    required this.htmlUrl,
  });

  factory GitCommitModel.fromJson(Map<String, dynamic> json) {
    return GitCommitModel(
      sha: json['sha'] as String? ?? '',
      shortSha: json['short_sha'] as String? ?? (json['sha'] != null && json['sha'].toString().length >= 7 ? json['sha'].toString().substring(0, 7) : ''),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '',
      authorLogin: json['author_login'] as String? ?? '',
      authoredAt: json['authored_at'] != null ? DateTime.tryParse(json['authored_at'].toString()) : null,
      htmlUrl: json['html_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'sha': sha,
    'short_sha': shortSha,
    'title': title,
    'message': message,
    'author_name': authorName,
    'author_login': authorLogin,
    'authored_at': authoredAt?.toIso8601String(),
    'html_url': htmlUrl,
  };
}

class PullRequestModel {
  final int number;
  final String title;
  final String state; // 'open', 'closed'
  final bool isMerged;
  final bool isDraft;
  final String authorLogin;
  final String headBranch;
  final String baseBranch;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final DateTime? mergedAt;
  final String htmlUrl;
  final String? body;
  final int commitsCount;
  final int additions;
  final int deletions;
  final int changedFiles;
  final String? mergeableState;

  PullRequestModel({
    required this.number,
    required this.title,
    required this.state,
    this.isMerged = false,
    this.isDraft = false,
    required this.authorLogin,
    required this.headBranch,
    required this.baseBranch,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.mergedAt,
    required this.htmlUrl,
    this.body,
    this.commitsCount = 0,
    this.additions = 0,
    this.deletions = 0,
    this.changedFiles = 0,
    this.mergeableState,
  });

  /// Section 8 status badge mapping:
  /// Show "Merged" when merged is true, "Draft" when draft is true, otherwise "Open" or "Closed"
  String get displayBadge {
    if (isMerged) return 'Merged';
    if (isDraft) return 'Draft';
    if (state.toLowerCase() == 'open') return 'Open';
    return 'Closed';
  }

  factory PullRequestModel.fromJson(Map<String, dynamic> json) {
    return PullRequestModel(
      number: json['number'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      state: json['state'] as String? ?? 'open',
      isMerged: json['merged'] as bool? ?? false,
      isDraft: json['draft'] as bool? ?? false,
      authorLogin: json['author_login'] as String? ?? '',
      headBranch: json['head_branch'] as String? ?? '',
      baseBranch: json['base_branch'] as String? ?? 'main',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at'].toString()) : null,
      mergedAt: json['merged_at'] != null ? DateTime.tryParse(json['merged_at'].toString()) : null,
      htmlUrl: json['html_url'] as String? ?? '',
      body: json['body'] as String?,
      commitsCount: json['commits'] as int? ?? 0,
      additions: json['additions'] as int? ?? 0,
      deletions: json['deletions'] as int? ?? 0,
      changedFiles: json['changed_files'] as int? ?? 0,
      mergeableState: json['mergeable_state'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'state': state,
    'merged': isMerged,
    'draft': isDraft,
    'author_login': authorLogin,
    'head_branch': headBranch,
    'base_branch': baseBranch,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'closed_at': closedAt?.toIso8601String(),
    'merged_at': mergedAt?.toIso8601String(),
    'html_url': htmlUrl,
    'body': body,
    'commits': commitsCount,
    'additions': additions,
    'deletions': deletions,
    'changed_files': changedFiles,
    'mergeable_state': mergeableState,
  };
}

class WorkflowRunModel {
  final int id;
  final String name;
  final int runNumber;
  final String event;
  final String status; // queued, in_progress, completed, etc.
  final String? conclusion; // success, failure, cancelled, timed_out, startup_failure, etc.
  final String branch;
  final String headSha;
  final String actorLogin;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? runStartedAt;
  final String htmlUrl;

  WorkflowRunModel({
    required this.id,
    required this.name,
    required this.runNumber,
    required this.event,
    required this.status,
    this.conclusion,
    required this.branch,
    required this.headSha,
    required this.actorLogin,
    this.createdAt,
    this.updatedAt,
    this.runStartedAt,
    required this.htmlUrl,
  });

  /// Section 8 mapping:
  /// status & conclusion -> Show as (Queued, Running, Passed, Failed, Cancelled, Skipped, Needs attention)
  String get displayStatus {
    final s = status.toLowerCase();
    final c = conclusion?.toLowerCase();

    if (s == 'queued' || s == 'waiting' || s == 'pending' || s == 'requested') {
      return 'Queued';
    }
    if (s == 'in_progress') {
      return 'Running';
    }
    if (s == 'completed') {
      if (c == 'success') return 'Passed';
      if (c == 'failure' || c == 'timed_out' || c == 'startup_failure') return 'Failed';
      if (c == 'cancelled') return 'Cancelled';
      if (c == 'skipped' || c == 'neutral') return 'Skipped';
      if (c == 'action_required' || c == 'stale') return 'Needs attention';
      return c != null && c.isNotEmpty ? c[0].toUpperCase() + c.substring(1) : 'Completed';
    }
    return s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : 'Unknown';
  }

  bool get isFailed => displayStatus == 'Failed';
  bool get isPassed => displayStatus == 'Passed';
  bool get isRunning => displayStatus == 'Running';

  factory WorkflowRunModel.fromJson(Map<String, dynamic> json) {
    return WorkflowRunModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'CI',
      runNumber: json['run_number'] as int? ?? (json['id'] as int? ?? 0),
      event: json['event'] as String? ?? 'push',
      status: json['status'] as String? ?? 'completed',
      conclusion: json['conclusion'] as String?,
      branch: json['branch'] as String? ?? 'main',
      headSha: json['head_sha'] as String? ?? '',
      actorLogin: json['actor_login'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      runStartedAt: json['run_started_at'] != null ? DateTime.tryParse(json['run_started_at'].toString()) : null,
      htmlUrl: json['html_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'run_number': runNumber,
    'event': event,
    'status': status,
    'conclusion': conclusion,
    'branch': branch,
    'head_sha': headSha,
    'actor_login': actorLogin,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'run_started_at': runStartedAt?.toIso8601String(),
    'html_url': htmlUrl,
  };
}

class WorkflowStepModel {
  final int number;
  final String name;
  final String status;
  final String? conclusion;

  WorkflowStepModel({
    required this.number,
    required this.name,
    required this.status,
    this.conclusion,
  });

  bool get isPassed => conclusion?.toLowerCase() == 'success';
  bool get isFailed => conclusion?.toLowerCase() == 'failure';

  factory WorkflowStepModel.fromJson(Map<String, dynamic> json) {
    return WorkflowStepModel(
      number: json['number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
      conclusion: json['conclusion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'status': status,
    'conclusion': conclusion,
  };
}

class WorkflowJobModel {
  final int id;
  final String name;
  final String status;
  final String? conclusion;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String htmlUrl;
  final List<WorkflowStepModel> steps;

  WorkflowJobModel({
    required this.id,
    required this.name,
    required this.status,
    this.conclusion,
    this.startedAt,
    this.completedAt,
    required this.htmlUrl,
    required this.steps,
  });

  WorkflowStepModel? get failedStep {
    try {
      return steps.firstWhere((step) => step.isFailed);
    } catch (_) {
      return null;
    }
  }

  String get durationString {
    if (startedAt != null && completedAt != null) {
      final diff = completedAt!.difference(startedAt!);
      final m = diff.inMinutes;
      final s = diff.inSeconds % 60;
      return '${m}m ${s}s';
    }
    return '2m 14s';
  }

  factory WorkflowJobModel.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List<dynamic>? ?? [];
    return WorkflowJobModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'build',
      status: json['status'] as String? ?? 'completed',
      conclusion: json['conclusion'] as String?,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      htmlUrl: json['html_url'] as String? ?? '',
      steps: rawSteps.map((s) => WorkflowStepModel.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status,
    'conclusion': conclusion,
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'html_url': htmlUrl,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
}
