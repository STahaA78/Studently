import 'package:studently/models/backend_config.dart';

class Teacher {
  final String id;
  final String title;
  final String name;
  final String? email;
  final String? linkedinProfile;
  final Department department;
  final Campus campus;
  final String? profile;
  final double rating;
  final int reviewCount;
  final bool approved;
  final DateTime? createdAt;

  Teacher({
    required this.id,
    required this.title,
    required this.name,
    this.email,
    this.linkedinProfile,
    required this.department,
    required this.campus,
    this.profile,
    required this.rating,
    required this.reviewCount,
    required this.approved,
    this.createdAt,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: json['email']?.toString(),
      linkedinProfile:
          (json['linkedinProfile'] ?? json['linkedin_profile'])?.toString(),
      department: json['department'] != null
          ? Department.fromJson(
              (json['department'] as Map).cast<String, dynamic>(),
            )
          : Department(name: '', code: ''),
      campus: json['campus'] != null
          ? Campus.fromJson((json['campus'] as Map).cast<String, dynamic>())
          : Campus(name: '', code: ''),
      profile: json['profile']?.toString(),
      rating: (json['rating'] as num? ?? 0).toDouble(),
      reviewCount: (json['review_count'] as num? ?? 0).toInt(),
      approved: json['approved'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'name': name,
      'email': email,
      'linkedinProfile': linkedinProfile,
      'department': department.toJson(),
      'campus': campus.toJson(),
      'profile': profile,
      'rating': rating,
      'review_count': reviewCount,
      'approved': approved,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  Teacher copyWith({
    String? id,
    String? title,
    String? name,
    String? email,
    String? linkedinProfile,
    Department? department,
    Campus? campus,
    String? profile,
    double? rating,
    int? reviewCount,
    bool? approved,
    DateTime? createdAt,
  }) {
    return Teacher(
      id: id ?? this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      email: email ?? this.email,
      linkedinProfile: linkedinProfile ?? this.linkedinProfile,
      department: department ?? this.department,
      campus: campus ?? this.campus,
      profile: profile ?? this.profile,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      approved: approved ?? this.approved,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TeacherReview {
  final String id;
  final String teacherId;
  final String authorId;
  final String authorName;
  final String? authorPic;
  final String? profile;
  final bool anonymous;
  final bool approved;
  final String content;
  final int rating;
  final DateTime timestamp;

  TeacherReview({
    required this.id,
    required this.teacherId,
    required this.authorId,
    required this.authorName,
    this.authorPic,
    this.profile,
    this.anonymous = false,
    this.approved = false,
    required this.content,
    required this.rating,
    required this.timestamp,
  });

  factory TeacherReview.fromJson(Map<String, dynamic> json) {
    final timestampText = json['timestamp'].toString();
    final hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(timestampText);
    final parsedTimestamp = DateTime.parse(
      hasTimezone ? timestampText : '${timestampText}Z',
    ).toLocal();
    return TeacherReview(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      teacherId: (json['teacherId'] ?? json['teacher_id'] ?? '').toString(),
      authorId: (json['authorId'] ?? json['author_id'] ?? '').toString(),
      authorName: (json['authorName'] ?? json['author_name'] ?? 'User')
          .toString(),
      authorPic: (json['profile'] ?? json['authorPic'] ?? json['author_pic'])
          ?.toString(),
      profile: (json['profile'] ?? json['authorPic'] ?? json['author_pic'])
          ?.toString(),
      anonymous: json['anonymous'] ?? false,
      approved: json['approved'] ?? false,
      content: (json['content'] ?? '').toString(),
      rating: (json['rating'] as num? ?? 0).toInt(),
      timestamp: parsedTimestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'teacherId': teacherId,
      'authorId': authorId,
      'authorName': authorName,
      'authorPic': authorPic,
      'profile': profile,
      'anonymous': anonymous,
      'approved': approved,
      'content': content,
      'rating': rating,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class TeacherDetail {
  final Teacher teacher;
  final List<TeacherReview> reviews;

  TeacherDetail({required this.teacher, required this.reviews});

  factory TeacherDetail.fromJson(Map<String, dynamic> json) {
    return TeacherDetail(
      teacher: Teacher.fromJson((json['teacher'] as Map).cast<String, dynamic>()),
      reviews: (json['reviews'] as List? ?? [])
          .map((e) => TeacherReview.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TeacherCreateRequest {
  final String title;
  final String name;
  final String? email;
  final String? linkedinProfile;
  final Department department;
  final Campus campus;
  final String? profile;

  TeacherCreateRequest({
    required this.title,
    required this.name,
    this.email,
    this.linkedinProfile,
    required this.department,
    required this.campus,
    this.profile,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'name': name,
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (linkedinProfile != null && linkedinProfile!.trim().isNotEmpty)
        'linkedinProfile': linkedinProfile!.trim(),
      'department': department.toJson(),
      'campus': campus.toJson(),
      if (profile != null && profile!.trim().isNotEmpty) 'profile': profile!.trim(),
    };
  }
}

class TeacherReviewCreateRequest {
  final String content;
  final int rating;
  final bool anonymous;

  TeacherReviewCreateRequest({
    required this.content,
    required this.rating,
    this.anonymous = false,
  });

  Map<String, dynamic> toJson() {
    return {'content': content, 'rating': rating, 'anonymous': anonymous};
  }
}
