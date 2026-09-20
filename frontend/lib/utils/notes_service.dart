class Note {
  final String id;
  String title;
  String content;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });
}

class NotesService {
  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  final List<Note> notes = [
    Note(
      id: "1",
      title: "AI Research Idea",
      content: "Explore how artificial intelligence can improve disease detection in early-stage...",
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Note(
      id: "2",
      title: "Literature Notes",
      content: "Key takeaways from the Smith et al. (2023) paper on neural networks...",
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Note(
      id: "3",
      title: "Methodology Thought",
      content: "Possible quantitative approach for the upcoming study involves a mixed-methods...",
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  void addNote(Note note) => notes.insert(0, note);
  void updateNote(Note note) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) notes[index] = note;
  }
  void deleteNote(String id) => notes.removeWhere((n) => n.id == id);
}