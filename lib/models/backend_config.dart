class Department {
  final String name;
  Department({required this.name});
}

class Interest {
  final String name;
  final String emoji;
  Interest({required this.name, required this.emoji});
  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'emoji': emoji,
    };
  }
}

class InterestCategory {
  final String category;
  final List<Interest> data;
  InterestCategory({required this.category, required this.data});
}

class CurrentTerm {
  final String term;
  final String year;
  CurrentTerm({required this.term, required this.year});
}

class BatchRange {
  final int start;
  final int end;
  BatchRange({required this.start, required this.end});
}

class BackendConfig {
  List<Department> departments;
  List<InterestCategory> interests;
  BatchRange batchRange; 
  CurrentTerm currentTerm;

  BackendConfig({
    required this.departments,
    required this.interests,
    required this.batchRange,
    required this.currentTerm,
  });

  factory BackendConfig.fromJson(Map<String, dynamic> json) {
    return BackendConfig(
      departments: (json['departments'] as List)
          .map((dept) => Department(name: dept['name']))
          .toList(),
      interests: (json['interests'] as List)
          .map((cat) => InterestCategory(
                category: cat['category'],
                data: (cat['data'] as List)
                    .map((intst) => Interest(
                          name: intst['name'],
                          emoji: intst['emoji'],
                        ))
                    .toList(),
              ))
          .toList(),
      batchRange: BatchRange(
        start: json['batch_range']['start'],
        end: json['batch_range']['end'],
      ),
      currentTerm: CurrentTerm(
        term: json['current_term']['semester'],
        year: json['current_term']['year'].toString(),
      ),
    );
  }
}