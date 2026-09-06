import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/notes_service.dart';

class NewNoteScreen extends StatefulWidget {
  final Note? note; // null = create new, not null = edit

  const NewNoteScreen({super.key, this.note});

  @override
  State<NewNoteScreen> createState() => _NewNoteScreenState();
}

class _NewNoteScreenState extends State<NewNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final NotesService _notesService = NotesService();
  bool _isAutoSaved = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? "");
    _contentController = TextEditingController(text: widget.note?.content ?? "");
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Note is empty")),
      );
      return;
    }

    if (widget.note == null) {
      // Create new
      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.isEmpty ? "Untitled" : title,
        content: content,
        updatedAt: DateTime.now(),
      );
      _notesService.addNote(newNote);
    } else {
      // Update existing
      widget.note!.title = title.isEmpty ? "Untitled" : title;
      widget.note!.content = content;
      widget.note!.updatedAt = DateTime.now();
      _notesService.updateNote(widget.note!);
    }

    setState(() => _isAutoSaved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Note saved"), duration: Duration(seconds: 1)),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              "New Note",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 17),
            ),
            if (_isAutoSaved)
              const Text(
                "Auto-saved",
                style: TextStyle(fontSize: 11, color: AppColors.success),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveNote,
            child: const Text(
              "Save",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Title
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: "Note title",
                hintStyle: TextStyle(color: AppColors.hintText, fontWeight: FontWeight.w500),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),

            // Content
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 15, height: 1.5),
                decoration: const InputDecoration(
                  hintText: "Start writing...",
                  hintStyle: TextStyle(color: AppColors.hintText),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}