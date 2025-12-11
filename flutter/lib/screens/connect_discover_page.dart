import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';

class ConnectDiscoverPage extends StatefulWidget {
  const ConnectDiscoverPage({super.key});

  @override
  State<ConnectDiscoverPage> createState() => _ConnectDiscoverPageState();
}

class _ConnectDiscoverPageState extends State<ConnectDiscoverPage> {
  final Color blue = const Color(0xFF1976D2);
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> students = [
    {
      "name": "Taha Ahmed",
      "gender": "Male",
      "department": "Computer Science",
      "batch": "2022",
      "bio":
          "Passionate about AI and machine learning. Looking for collaborators on a final year project focusing on neural networks.",
      "interests": ["AI", "Machine Learning", "Data Science", "Python", "Web Dev"],
    },
    {
      "name": "Sara Malik",
      "gender": "Female",
      "department": "Software Engineering",
      "batch": "2021",
      "bio": "UI/UX enthusiast and Flutter developer. Excited about product design and creative coding.",
      "interests": ["UI/UX", "Flutter", "Design", "Art", "Frontend"],
    },
    {
      "name": "Ali Khan",
      "gender": "Male",
      "department": "Information Technology",
      "batch": "2023",
      "bio": "Interested in cybersecurity and ethical hacking. Open to group research and Capture-the-Flag events.",
      "interests": ["Cybersecurity", "Networking", "Linux", "Python"],
    },
    {
      "name": "Fatima Noor",
      "gender": "Female",
      "department": "Artificial Intelligence",
      "batch": "2022",
      "bio": "Aspiring data scientist. I love working with datasets and visualizing insights using Python and Tableau.",
      "interests": ["Data Science", "Python", "Visualization", "AI"],
    },
  ];

  List<Map<String, dynamic>> filteredStudents = [];

  @override
  void initState() {
    super.initState();
    filteredStudents = List.from(students);
    _searchController.addListener(_filterStudents);
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredStudents = students
          .where((s) => s["name"].toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double maxWidth = isLandscape ? 600 : screenSize.width * 0.95;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Connect",
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(12), // distance below AppBar
          child: Column(
            children: [
              SizedBox(height: 8), // how far down you want the line
              Container(
                height: 1,
                color: Color(0xFFE0E0E0),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              // 🔍 Search bar
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    hintText: "Search Students...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // Student cards
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return _buildStudentCard(student);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 1),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  student["name"].split(' ').map((e) => e[0]).take(2).join(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student["name"],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    student["gender"],
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          const Text("Department", style: TextStyle(fontWeight: FontWeight.w700)),
          Text(student["department"], style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 8),

          const Text("Batch", style: TextStyle(fontWeight: FontWeight.w700)),
          Text(student["batch"], style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 8),

          const Text("Bio", style: TextStyle(fontWeight: FontWeight.w700)),
          Text(student["bio"], style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 10),

          const Text("Interests", style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: -4,
            children: (student["interests"] as List<String>)
                .map((interest) => Chip(
                      label: Text(
                        interest,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
