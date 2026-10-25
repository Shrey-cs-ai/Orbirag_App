import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'ori_chatbot_screen.dart';
import 'literature_retrieval_screen.dart';
import 'profile_screen.dart';
import 'paper_orbit_screen.dart';

// ---------------------------------------------------------------------------
// API client (kept inside the screen file as requested)
// ---------------------------------------------------------------------------
class _GapApi {
  static const _base = 'http://localhost:8001';

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$_base$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode >= 400) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    final r = await http.get(Uri.parse('$_base$path'));
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> start(String topic, String? rq) =>
      _post('/api/gap/start', {'topic': topic, 'research_question': rq});

  static Future<Map<String, dynamic>> getAnalysis(int id) =>
      _get('/api/gap/$id');

  static Future<Map<String, dynamic>> addPapers(int id, List<Map<String, dynamic>> papers) async {
    final r = await http.post(
      Uri.parse('$_base/api/gap/$id/papers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(papers),
    );
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> extract(int id) =>
      _post('/api/gap/$id/extract', {});

  static Future<Map<String, dynamic>> detectGaps(int id) =>
      _post('/api/gap/$id/detect-gaps', {});

  static Future<Map<String, dynamic>> validateGap(
      int analysisId, int gapId, String status) async {
    final r = await http.patch(
      Uri.parse('$_base/api/gap/$analysisId/gaps/$gapId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> generateDirection(int analysisId, int gapId) =>
      _post('/api/gap/$analysisId/gaps/$gapId/direction', {});

  static Future<Map<String, dynamic>> save(int id) =>
      _post('/api/gap/$id/save', {});
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class GapResearchScreen extends StatefulWidget {
  const GapResearchScreen({super.key});

  @override
  State<GapResearchScreen> createState() => _GapResearchScreenState();
}

class _GapResearchScreenState extends State<GapResearchScreen> {
  final _topicCtrl = TextEditingController();
  final _rqCtrl = TextEditingController();

  int? _analysisId;
  String _status = 'draft';
  List<Map<String, dynamic>> _papers = [];
  List<Map<String, dynamic>> _gaps = [];

  bool _busy = false;
  String _busyLabel = '';
  int _step = 0; // 0 topic, 1 papers, 2 extract, 3 detect, 4 validate, 5 direction
  final int _currentIndex = 2; // Research tab

  @override
  void dispose() {
    _topicCtrl.dispose();
    _rqCtrl.dispose();
    super.dispose();
  }

  // -------- Bottom Nav Handler --------
  void _onBottomNavTap(int index) {
    if (index == _currentIndex) return;

    final Widget screen;
    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;
      case 1:
        screen = const OriChatScreen();
        break;
      case 2:
        screen = const LiteratureRetrievalScreen();
        break;
      case 3:
        screen = const ProfileScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  // -------- UI helpers --------
  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(String label, Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      await fn();
    } catch (e) {
      _msg('$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = '';
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_analysisId == null) return;
    final a = await _GapApi.getAnalysis(_analysisId!);
    if (!mounted) return;
    setState(() {
      _status = a['status'] ?? 'draft';
      _papers = List<Map<String, dynamic>>.from(a['papers'] ?? []);
      _gaps = List<Map<String, dynamic>>.from(a['gaps'] ?? []);
    });
  }

  // -------- Actions --------
  Future<void> _start() async {
    if (_topicCtrl.text.trim().isEmpty) {
      _msg('Enter a topic first');
      return;
    }
    await _run('Starting analysis', () async {
      final res = await _GapApi.start(
        _topicCtrl.text.trim(),
        _rqCtrl.text.trim().isEmpty ? null : _rqCtrl.text.trim(),
      );
      _analysisId = res['analysis_id'] as int;
      setState(() => _step = 1);
      await _refresh();
    });
  }

  Future<void> _addPaperDialog() async {
    if (_analysisId == null) return;
    final titleC = TextEditingController();
    final abstractC = TextEditingController();
    final authorsC = TextEditingController();
    final yearC = TextEditingController();
    final venueC = TextEditingController();
    final urlC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool dialogLoading = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.white,
              title: const Text(
                'Add paper',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleC,
                      enabled: !dialogLoading,
                      decoration: const InputDecoration(
                        labelText: 'Title (Optional if URL/DOI provided)',
                        hintText: 'e.g. Attention Is All You Need',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: urlC,
                      enabled: !dialogLoading,
                      decoration: const InputDecoration(
                        labelText: 'URL / DOI',
                        hintText: 'e.g. 10.1145/3290605.3300823 or arXiv URL',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: authorsC,
                      enabled: !dialogLoading,
                      decoration: const InputDecoration(labelText: 'Authors'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: yearC,
                      enabled: !dialogLoading,
                      decoration: const InputDecoration(labelText: 'Year'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: venueC,
                      enabled: !dialogLoading,
                      decoration: const InputDecoration(labelText: 'Venue'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: abstractC,
                      enabled: !dialogLoading,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Abstract (recommended)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (dialogLoading) ...[
                      const SizedBox(height: 16),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Extracting metadata & adding paper...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: dialogLoading
                      ? null
                      : () async {
                          final title = titleC.text.trim();
                          final urlOrDoi = urlC.text.trim();

                          if (title.isEmpty && urlOrDoi.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Provide a Title or a URL / DOI';
                            });
                            return;
                          }

                          setDialogState(() {
                            dialogLoading = true;
                            dialogError = null;
                          });

                          try {
                            await _GapApi.addPapers(_analysisId!, [
                              {
                                'title': title,
                                'authors': authorsC.text.trim(),
                                'year': yearC.text.trim(),
                                'venue': venueC.text.trim(),
                                'url': urlOrDoi,
                                'doi': urlOrDoi.startsWith('10.') ? urlOrDoi : '',
                                'abstract': abstractC.text.trim(),
                              }
                            ]);
                            if (ctx.mounted) {
                              Navigator.pop(ctx, true);
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() {
                                dialogLoading = false;
                                dialogError = 'Error adding paper: $e';
                              });
                            }
                          }
                        },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    titleC.dispose();
    abstractC.dispose();
    authorsC.dispose();
    yearC.dispose();
    venueC.dispose();
    urlC.dispose();

    if (ok == true) {
      await _refresh();
      _msg('Paper added');
    }
  }


  Future<void> _runExtraction() async {
    if (_analysisId == null) return;
    await _run('Extracting evidence (AI)', () async {
      final res = await _GapApi.extract(_analysisId!);
      setState(() {
        _status = res['status'] ?? 'analyzed';
        _papers = List<Map<String, dynamic>>.from(res['papers'] ?? []);
        _gaps = List<Map<String, dynamic>>.from(res['gaps'] ?? []);
        _step = 3;
      });
    });
  }

  Future<void> _detectGaps() async {
    if (_analysisId == null) return;
    await _run('Detecting gaps (AI)', () async {
      final res = await _GapApi.detectGaps(_analysisId!);
      setState(() {
        _gaps = List<Map<String, dynamic>>.from(res['gaps'] ?? []);
        _step = 4;
      });
    });
  }

  Future<void> _validate(int gapId, String status) async {
    await _run('Updating', () async {
      await _GapApi.validateGap(_analysisId!, gapId, status);
      await _refresh();
    });
  }

  Future<void> _generateDirection(int gapId) async {
    await _run('Generating research direction', () async {
      await _GapApi.generateDirection(_analysisId!, gapId);
      await _refresh();
      setState(() => _step = 5);
    });
  }

  Future<void> _save() async {
    await _run('Saving', () async {
      await _GapApi.save(_analysisId!);
      await _refresh();
      _msg('✅ Gap analysis saved to project');
    });
  }

  // -------- Build --------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "Orbirag",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaperOrbitScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Research Gap Analysis',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Identify evidence-backed research gaps and novel directions',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _stepChip(0, 'Topic'),
                      _stepChip(1, 'Papers'),
                      _stepChip(2, 'Extract'),
                      _stepChip(3, 'Detect'),
                      _stepChip(4, 'Validate'),
                      _stepChip(5, 'Direction'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTopicSection(),
                if (_analysisId != null) ...[
                  const SizedBox(height: 24),
                  _buildPapersSection(),
                  const SizedBox(height: 24),
                  _buildExtractSection(),
                ],
                if (_gaps.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildGapsSection(),
                ],
                if (_status == 'saved' || _status == 'analyzed') ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _analysisId == null ? null : _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Save to Project', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_busy) _loadingOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  Widget _loadingOverlay() => Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: Card(
            color: AppColors.cardBg,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(_busyLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _stepChip(int idx, String label) {
    final active = _step == idx;
    final done = _step > idx;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withValues(alpha: 0.12)
            : done
                ? Colors.green.withValues(alpha: 0.08)
                : AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.4)
              : done
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done
                ? Icons.check_circle
                : (active ? Icons.circle : Icons.circle_outlined),
            size: 16,
            color: done ? Colors.green : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$idx. $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: done
                  ? Colors.green.shade800
                  : (active ? AppColors.primary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTopicSection() => Card(
        color: AppColors.cardBg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. Research topic',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _topicCtrl,
                decoration: const InputDecoration(
                  labelText: 'Topic *',
                  hintText: 'e.g. AI for Nepali Sign Language Recognition',
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rqCtrl,
                decoration: const InputDecoration(
                  labelText: 'Research question (optional)',
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _analysisId == null ? _start : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(_analysisId == null ? 'Start Analysis' : 'Analysis started'),
              ),
            ],
          ),
        ),
      );

  Widget _buildPapersSection() => Card(
        color: AppColors.cardBg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('2. Evidence set',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text(
                    '${_papers.length} papers',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final p in _papers)
                ListTile(
                  dense: true,
                  title: Text(p['title'] ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${p['authors'] ?? ''} ${p['year'] ?? ''}'.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: (p['is_extracted'] == true)
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                      : const Icon(Icons.schedule, size: 18),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addPaperDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Paper'),
              ),
            ],
          ),
        ),
      );

  Widget _buildExtractSection() {
    final allExtracted = _papers.isNotEmpty &&
        _papers.every((p) => p['is_extracted'] == true);
    return Card(
      color: AppColors.cardBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('3. Extract & analyze',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (!allExtracted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _papers.length >= 2 ? _runExtraction : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Extract Evidence (AI)'),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _papers.length >= 2 ? _detectGaps : null,
                icon: const Icon(Icons.search),
                label: const Text('Detect Gaps (AI)'),
              ),
            if (_papers.length < 2)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Need at least 2 papers',
                    style: TextStyle(fontSize: 12, color: Colors.orange)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGapsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('4. Potential gaps',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (final g in _gaps) _gapCard(g),
        ],
      );

  Widget _gapCard(Map<String, dynamic> g) {
    final status = g['status'] ?? 'pending';
    final color = status == 'accepted'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : status == 'uncertain'
                ? Colors.orange
                : Colors.blueGrey;

    return Card(
      color: AppColors.cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (g['gap_type'] ?? '').toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${g['confidence'] ?? 'unverified'}'.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              g['description'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if ((g['evidence_summary'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Evidence: ${g['evidence_summary']}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
            if ((g['confidence_reason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Why not high: ${g['confidence_reason']}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _validate(g['id'] as int, 'accepted'),
                  child: const Text('Accept', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton(
                  onPressed: () => _validate(g['id'] as int, 'rejected'),
                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton(
                  onPressed: () => _validate(g['id'] as int, 'uncertain'),
                  child: const Text('Uncertain', style: TextStyle(fontSize: 12)),
                ),
                if (status == 'accepted' || status == 'uncertain')
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _generateDirection(g['id'] as int),
                    child: const Text('Generate Direction',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            if ((g['directions'] as List?)?.isNotEmpty == true) ...[
              const Divider(height: 20),
              const Text('5. Research direction',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              for (final d in (g['directions'] as List))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((d['research_question'] ?? '').toString().isNotEmpty)
                        Text('RQ: ${d['research_question']}',
                            style: const TextStyle(fontSize: 12)),
                      if ((d['objective'] ?? '').toString().isNotEmpty)
                        Text('Objective: ${d['objective']}',
                            style: const TextStyle(fontSize: 12)),
                      if ((d['hypothesis'] ?? '').toString().isNotEmpty)
                        Text('Hypothesis: ${d['hypothesis']}',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}