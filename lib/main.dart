import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// 引入拆分後的模組
import 'models/note.dart';
import 'models/scale_data.dart';
import 'utils/audio_gen.dart';
import 'widgets/painters.dart';

void main() {
  runApp(const MaterialApp(home: ViolinApp()));
}

class ViolinApp extends StatefulWidget {
  const ViolinApp({super.key});

  @override
  State<ViolinApp> createState() => _ViolinAppState();
}

class _ViolinAppState extends State<ViolinApp> {
  final AudioPlayer _player = AudioPlayer();
  final Random _rng = Random();

  ViolinNote? _currentNote;
  bool _isPlaying = false;
  bool _isAnswerVisible = false;

  // --- 設定變數 ---
  double _referencePitch = 442.0;
  Set<MusicalKey> _selectedKeys = {MusicalKey.D_Major};
  bool _isMultiSelectMode = false;

  MusicalKey _currentQuestionKey = MusicalKey.D_Major;
  ViolinPosition _currentPosition = ViolinPosition.first;

  PracticeMode _practiceMode = PracticeMode.staffToFinger;
  RangeValues _rangePercent = const RangeValues(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _nextNote();
  }

  Future<void> _nextNote() async {
    await _player.stop();
    if (_selectedKeys.isEmpty) return;

    List<MusicalKey> availableKeys = _selectedKeys.toList();
    _currentQuestionKey = availableKeys[_rng.nextInt(availableKeys.length)];

    Set<String> validBaseNames = keyNotesMap[_currentQuestionKey] ?? {};
    List<ViolinNote> validNotes = allNotes.where((note) {
      if (_currentQuestionKey == MusicalKey.F_Sharp_Major &&
          note.baseName == 'F')
        return true;
      if (_currentQuestionKey == MusicalKey.C_Sharp_Major &&
          (note.baseName == 'F' || note.baseName == 'C'))
        return true;
      if (_currentQuestionKey == MusicalKey.Cb_Major &&
          (note.baseName == 'B' || note.baseName == 'E'))
        return true;

      return validBaseNames.contains(note.baseName);
    }).toList();

    if (validNotes.isEmpty) return;

    int totalCount = validNotes.length;
    int startIndex = (_rangePercent.start * (totalCount - 1)).round();
    int endIndex = (_rangePercent.end * (totalCount - 1)).round();
    if (endIndex < startIndex) endIndex = startIndex;

    int randomIndex = startIndex + _rng.nextInt(endIndex - startIndex + 1);
    final note = validNotes[randomIndex];

    setState(() {
      _currentNote = note;
      _isPlaying = true;
      _isAnswerVisible = false;
    });

    double adjustedFrequency = note.frequency * (_referencePitch / 440.0);
    final Uint8List wavBytes = ToneGenerator.generateSineWave(
      frequency: adjustedFrequency,
      durationMs: 1500,
      sampleRate: 44100,
    );

    try {
      await _player.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint("Audio Error: $e");
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && _currentNote == note) {
      setState(() => _isPlaying = false);
    }
  }

  void _revealAnswer() {
    setState(() {
      _isAnswerVisible = true;
    });
  }

  String _getModeName(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.staffToFinger:
        return "看譜找指位";
      case PracticeMode.fingerToStaff:
        return "看指位猜音";
      case PracticeMode.earTraining:
        return "聽音辨音高";
    }
  }

  // --- 設定面板 ---
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            int total = allNotes.length;
            int sIdx = (_rangePercent.start * (total - 1)).round();
            int eIdx = (_rangePercent.end * (total - 1)).round();
            ViolinNote sNote = allNotes[sIdx];
            ViolinNote eNote = allNotes[eIdx];
            String startStr = sNote
                .getDisplayName(_selectedKeys.first)
                .replaceAll('\n', ' ');
            String endStr = eNote
                .getDisplayName(_selectedKeys.first)
                .replaceAll('\n', ' ');

            return Container(
              padding: const EdgeInsets.all(20),
              height: 750,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "設定 (Settings)",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "練習模式:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8.0,
                    children: PracticeMode.values.map((mode) {
                      return ChoiceChip(
                        label: Text(_getModeName(mode)),
                        selected: _practiceMode == mode,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => _practiceMode = mode);
                            setState(() => _nextNote());
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "把位 (Position):",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SegmentedButton<ViolinPosition>(
                    segments: const [
                      ButtonSegment(
                        value: ViolinPosition.first,
                        label: Text("First (第一)"),
                      ),
                      ButtonSegment(
                        value: ViolinPosition.third,
                        label: Text("Third (第三)"),
                      ),
                    ],
                    selected: {_currentPosition},
                    onSelectionChanged: (newVal) {
                      setModalState(() => _currentPosition = newVal.first);
                      setState(() => _currentPosition = newVal.first);
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "選擇調性:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Text("多選: "),
                          Switch(
                            value: _isMultiSelectMode,
                            onChanged: (val) {
                              setModalState(() => _isMultiSelectMode = val);
                              setState(() => _isMultiSelectMode = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isMultiSelectMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setModalState(() {
                            _isMultiSelectMode = true;
                            if (_selectedKeys.length ==
                                MusicalKey.values.length) {
                              _selectedKeys = {MusicalKey.C_Major};
                            } else {
                              _selectedKeys = Set.from(MusicalKey.values);
                            }
                          });
                          setState(() => _nextNote());
                        },
                        child: const Text("全選/重置"),
                      ),
                    ),

                  const SizedBox(height: 5),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Center(
                            child: SizedBox(
                              width: 120,
                              child: _buildKeyButton(
                                MusicalKey.C_Major,
                                setModalState,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text(
                                      "降記號 (b)",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    _buildKeyButton(
                                      MusicalKey.F_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.Bb_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.Eb_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.Ab_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.Db_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.Gb_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.Cb_Major,
                                      setModalState,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text(
                                      "升記號 (#)",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    _buildKeyButton(
                                      MusicalKey.G_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.D_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.A_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.E_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.B_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.F_Sharp_Major,
                                      setModalState,
                                    ),
                                    _buildKeyButton(
                                      MusicalKey.C_Sharp_Major,
                                      setModalState,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    "基準音:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SegmentedButton<double>(
                    segments: const [
                      ButtonSegment(value: 440.0, label: Text("440")),
                      ButtonSegment(value: 442.0, label: Text("442")),
                    ],
                    selected: {_referencePitch},
                    onSelectionChanged: (newVal) {
                      setModalState(() => _referencePitch = newVal.first);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "音域範圍:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "$startStr ~ $endStr",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _rangePercent,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (RangeValues values) {
                      setModalState(() => _rangePercent = values);
                      setState(() {});
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("完成"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKeyButton(MusicalKey key, StateSetter setModalState) {
    bool isSelected = _selectedKeys.contains(key);

    return GestureDetector(
      onTap: () {
        setModalState(() {
          if (_isMultiSelectMode) {
            if (isSelected) {
              if (_selectedKeys.length > 1) _selectedKeys.remove(key);
            } else {
              _selectedKeys.add(key);
            }
          } else {
            _selectedKeys = {key};
          }
        });
        setState(() => _nextNote());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        height: 55,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              key.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.blue[800] : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            CustomPaint(
              size: const Size(60, 20),
              painter: KeySignaturePainter(accidentals: key.accidentals),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showStaff = false;
    bool showFingerboardAnswer = false;

    switch (_practiceMode) {
      case PracticeMode.staffToFinger:
        showStaff = true;
        showFingerboardAnswer = _isAnswerVisible;
        break;
      case PracticeMode.fingerToStaff:
        showStaff = _isAnswerVisible;
        showFingerboardAnswer = true;
        break;
      case PracticeMode.earTraining:
        showStaff = _isAnswerVisible;
        showFingerboardAnswer = _isAnswerVisible;
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Violin Trainer"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 五線譜區域 (增加比例至 32% 以容納更多音)
          Expanded(
            flex: 32,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              // 使用 Padding 確保上下有緩衝
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: StaffPainter(
                      noteIndex: showStaff ? _currentNote?.staffIndex : null,
                      keySignature: _currentQuestionKey,
                    ),
                  ),
                  if (!showStaff)
                    const Icon(
                      Icons.visibility_off,
                      size: 50,
                      color: Colors.grey,
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // 2. 下半部區域 (68%)
          Expanded(
            flex: 68,
            child: Row(
              children: [
                // 左下：指板
                Expanded(
                  flex: 6,
                  child: Container(
                    color: const Color(0xFF222222),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 5,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size.infinite,
                          painter: ViolinFingerboardPainter(
                            targetNote: showFingerboardAnswer
                                ? _currentNote
                                : null,
                            currentKey: _currentQuestionKey,
                            currentPosition: _currentPosition,
                          ),
                        ),
                        if (_practiceMode == PracticeMode.staffToFinger &&
                            !_isAnswerVisible)
                          const Text(
                            "?",
                            style: TextStyle(
                              fontSize: 80,
                              color: Colors.white24,
                            ),
                          ),
                        if (_practiceMode == PracticeMode.earTraining &&
                            !_isAnswerVisible)
                          const Icon(
                            Icons.visibility_off,
                            size: 60,
                            color: Colors.white24,
                          ),
                      ],
                    ),
                  ),
                ),

                // 右下：資訊面板
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: const Border(
                        left: BorderSide(color: Colors.grey),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getModeName(_practiceMode),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (_isAnswerVisible) ...[
                          Text(
                            _currentNote
                                    ?.getDisplayName(_currentQuestionKey)
                                    .split('\n')[0] ??
                                "",
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            _currentNote?.solfege ?? "",
                            style: const TextStyle(
                              fontSize: 26,
                              color: Colors.black54,
                            ),
                          ),
                        ] else
                          const Text(
                            "?",
                            style: TextStyle(fontSize: 60, color: Colors.grey),
                          ),

                        const Spacer(),

                        IconButton(
                          onPressed: () async {
                            if (_currentNote != null) {
                              double adjFreq =
                                  _currentNote!.frequency *
                                  (_referencePitch / 440.0);
                              final wavBytes = ToneGenerator.generateSineWave(
                                frequency: adjFreq,
                                durationMs: 1000,
                                sampleRate: 44100,
                              );
                              await _player.stop();
                              await _player.play(BytesSource(wavBytes));
                            }
                          },
                          icon: const Icon(Icons.volume_up, size: 32),
                          color: Colors.grey[700],
                        ),

                        const Spacer(),

                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_isAnswerVisible) {
                                _nextNote();
                              } else {
                                _revealAnswer();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isAnswerVisible
                                  ? Colors.blue
                                  : Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _isAnswerVisible ? "Next" : "Answer",
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
