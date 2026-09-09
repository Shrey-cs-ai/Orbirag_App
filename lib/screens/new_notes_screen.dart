import 'dart:async'; // ← Added for Timer
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../services/notes_service.dart';
import '../widgets/bottom_nav_bar.dart';

class NewNoteScreen extends StatefulWidget {
  final Note? note;

  const NewNoteScreen({super.key, this.note});

  @override
  State<NewNoteScreen> createState() => _NewNoteScreenState();
}

class _NewNoteScreenState extends State<NewNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final NotesService _notesService = NotesService();
  bool _isAutoSaved = false;
  bool _hasChanges = false;
  Timer? _autoSaveTimer; // Now works with dart:async import
  int _selectedIndex = 0; // Home is index 0

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? "");
    _contentController = TextEditingController(text: widget.note?.content ?? "");
    
    // Listen for changes to enable auto-save
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
    // Reset auto-save timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!_hasChanges) return;
    await _saveNote(showSnackbar: false);
  }

  Future<void> _saveNote({bool showSnackbar = true}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Note is empty"),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final now = DateTime.now();

    if (widget.note == null) {
      // Create new note
      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.isEmpty ? "Untitled" : title,
        content: content,
        updatedAt: now,
      );
      await _notesService.addNote(newNote);
    } else {
      // Update existing note
      widget.note!.title = title.isEmpty ? "Untitled" : title;
      widget.note!.content = content;
      widget.note!.updatedAt = now;
      await _notesService.updateNote(widget.note!);
    }

    setState(() {
      _isAutoSaved = true;
      _hasChanges = false;
    });

    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Note saved"),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 1),
        ),
      );
    }

    // Return true to indicate changes were saved
    Navigator.pop(context, true);
  }

  Future<void> _deleteNote() async {
    if (widget.note == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _notesService.deleteNote(widget.note!.id);
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.note == null;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_hasChanges) {
              _saveNote(showSnackbar: false);
            }
            Navigator.pop(context);
          },
        ),
        title: Column(
          children: [
            Text(
              isNew ? "New Note" : "Edit Note",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 17,
              ),
            ),
            if (_isAutoSaved && !_hasChanges)
              const Text(
                "Auto-saved",
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                ),
              ),
            if (_hasChanges)
              const Text(
                "Unsaved changes",
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _deleteNote,
            ),
          TextButton(
            onPressed: () => _saveNote(showSnackbar: true),
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: "Note title",
                hintStyle: TextStyle(
                  color: AppColors.hintText,
                  fontWeight: FontWeight.w500,
                ),
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
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: "Start writing...",
                  hintStyle: TextStyle(color: AppColors.hintText),
                  border: InputBorder.none,
                ),
              ),
            ),

            // Word count
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '${_contentController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          final route = AppConstants.bottomNavItems[index]['route'] as String;
          Navigator.of(context).pushReplacementNamed(route);
        },
      ),
    );
  }
}