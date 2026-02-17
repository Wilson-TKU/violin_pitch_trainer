import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'models/note.dart';
import 'models/scale_data.dart';
import 'utils/audio_gen.dart';
import 'widgets/painters.dart';
import 'utils/violin_logic.dart';

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

  Set<ViolinPosition> _selectedPositions = {ViolinPosition.first};
  bool _isPositionMultiSelectMode = false;
  ViolinPosition _targetPosition = ViolinPosition.first;

  PracticeMode _practiceMode = PracticeMode.staffToFinger;

  // 預設範圍 (稍後會在 initState 自動調整)
  RangeValues _rangePercent = const RangeValues(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    // [NEW] 初始化時，自動將音域設定為當前把位的預設範圍
    _resetRangeToFitPosition();
    _nextNote();
  }

  // [Helper] 計算當前選取把位的「合法百分比範圍」
  // 回傳 (minPercent, maxPercent)
  ({double min, double max}) _getValidRangeForPositions() {
    if (_selectedPositions.isEmpty) return (min: 0.0, max: 1.0);

    int totalNotes = ViolinLogic.totalNotesCount;
    int globalMinIndex = totalNotes;
    int globalMaxIndex = -1;

    for (var pos in _selectedPositions) {
      var range = ViolinLogic.getPositionIndexRange(pos);
      if (range.minIndex < globalMinIndex) globalMinIndex = range.minIndex;
      if (range.maxIndex > globalMaxIndex) globalMaxIndex = range.maxIndex;
    }

    double minP = globalMinIndex / (totalNotes - 1);
    double maxP = globalMaxIndex / (totalNotes - 1);

    // 確保數值在 0~1 之間
    return (min: minP.clamp(0.0, 1.0), max: maxP.clamp(0.0, 1.0));
  }

  // [NEW] 強制將滑桿重置為該把位的最大範圍 (用於切換把位時)
  void _resetRangeToFitPosition() {
    var validRange = _getValidRangeForPositions();
    setState(() {
      _rangePercent = RangeValues(validRange.min, validRange.max);
    });
  }

  Future<void> _nextNote() async {
    await _player.stop();
    if (_selectedKeys.isEmpty || _selectedPositions.isEmpty) return;

    List<MusicalKey> availableKeys = _selectedKeys.toList();
    _currentQuestionKey = availableKeys[_rng.nextInt(availableKeys.length)];

    Set<String> validBaseNames = keyNotesMap[_currentQuestionKey] ?? {};

    List<ViolinNote> keyValidNotes = allNotes.where((note) {
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

    List<ViolinNote> positionValidNotes = keyValidNotes.where((note) {
      for (var pos in _selectedPositions) {
        if (ViolinLogic.isNoteInPosition(note, pos)) return true;
      }
      return false;
    }).toList();

    if (positionValidNotes.isEmpty) return;

    // 根據滑桿範圍過濾
    int globalTotal = allNotes.length;
    int minIndex = (_rangePercent.start * (globalTotal - 1)).round();
    int maxIndex = (_rangePercent.end * (globalTotal - 1)).round();

    List<ViolinNote> rangeFilteredNotes = positionValidNotes.where((note) {
      int idx = allNotes.indexOf(note);
      return idx >= minIndex && idx <= maxIndex;
    }).toList();

    if (rangeFilteredNotes.isEmpty) {
      rangeFilteredNotes = positionValidNotes;
    }

    final note = rangeFilteredNotes[_rng.nextInt(rangeFilteredNotes.length)];

    List<ViolinPosition> possiblePositions = _selectedPositions.where((pos) {
      return ViolinLogic.isNoteInPosition(note, pos);
    }).toList();

    ViolinPosition chosenPos = possiblePositions.isNotEmpty
        ? possiblePositions[_rng.nextInt(possiblePositions.length)]
        : _selectedPositions.first;

    setState(() {
      _currentNote = note;
      _targetPosition = chosenPos;
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

            // 取得目前的有效範圍限制
            var validRange = _getValidRangeForPositions();

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

                  // 1. 練習模式
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

                  // 2. 調性選擇
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

                  // 3. 把位選擇 (多選)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "把位 (Position):",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Text("多選: "),
                          Switch(
                            value: _isPositionMultiSelectMode,
                            onChanged: (val) {
                              setModalState(
                                () => _isPositionMultiSelectMode = val,
                              );
                              setState(() => _isPositionMultiSelectMode = val);
                              // 切換回單選時，只保留第一個
                              if (!val && _selectedPositions.length > 1) {
                                setModalState(() {
                                  _selectedPositions = {
                                    _selectedPositions.first,
                                  };
                                  _resetRangeToFitPosition(); // 自動重置音域
                                });
                                setState(() => _nextNote());
                              }
                            },
                          ),
                        ],
                      ),
                    ],
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
                    selected: _selectedPositions,
                    multiSelectionEnabled: _isPositionMultiSelectMode,
                    onSelectionChanged: (newValues) {
                      setModalState(() {
                        if (_isPositionMultiSelectMode) {
                          if (newValues.isEmpty) return;
                          _selectedPositions = newValues;
                        } else {
                          // 單選邏輯：強制替換
                          if (newValues.isNotEmpty) {
                            _selectedPositions = newValues;
                          }
                        }
                        // [NEW] 當把位改變時，自動把音域重置到該把位最大範圍
                        _resetRangeToFitPosition();
                      });
                      setState(() => _nextNote());
                    },
                  ),
                  const SizedBox(height: 10),

                  // 4. 音域範圍
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
                    divisions: 40, // 增加刻度讓調整更細
                    onChanged: (RangeValues values) {
                      // [NEW] 限制拖曳範圍：不能超出當前選定把位的物理限制
                      double clampedStart = values.start;
                      double clampedEnd = values.end;

                      // 限制下限
                      if (clampedStart < validRange.min)
                        clampedStart = validRange.min;
                      // 限制上限
                      if (clampedEnd > validRange.max)
                        clampedEnd = validRange.max;
                      // 防止交錯
                      if (clampedStart > clampedEnd) clampedStart = clampedEnd;

                      setModalState(
                        () => _rangePercent = RangeValues(
                          clampedStart,
                          clampedEnd,
                        ),
                      );
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 10),

                  // 5. 基準音
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
      body: Row(
        children: [
          // 左側: 指板
          Expanded(
            flex: 35,
            child: Container(
              color: const Color(0xFF222222),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: ViolinFingerboardPainter(
                      targetNote: showFingerboardAnswer ? _currentNote : null,
                      currentKey: _currentQuestionKey,
                      currentPosition: _targetPosition,
                    ),
                  ),
                  if (_practiceMode == PracticeMode.staffToFinger &&
                      !_isAnswerVisible)
                    const Center(
                      child: Text(
                        "?",
                        style: TextStyle(fontSize: 80, color: Colors.white24),
                      ),
                    ),
                  if (_practiceMode == PracticeMode.earTraining &&
                      !_isAnswerVisible)
                    const Center(
                      child: Icon(
                        Icons.visibility_off,
                        size: 60,
                        color: Colors.white24,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1, thickness: 1),

          // 右側: 譜與操作
          Expanded(
            flex: 65,
            child: Column(
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size.infinite,
                          painter: StaffPainter(
                            noteIndex: showStaff
                                ? _currentNote?.staffIndex
                                : null,
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

                Expanded(
                  flex: 6,
                  child: Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${_getModeName(_practiceMode)} - ${_currentQuestionKey.label} (${_targetPosition.label.split(' ')[0]})",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_isAnswerVisible) ...[
                          Text(
                            _currentNote
                                    ?.getDisplayName(_currentQuestionKey)
                                    .split('\n')[0] ??
                                "",
                            style: const TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            _currentNote?.solfege ?? "",
                            style: const TextStyle(
                              fontSize: 30,
                              color: Colors.black54,
                            ),
                          ),
                        ] else
                          const Text(
                            "?",
                            style: TextStyle(fontSize: 80, color: Colors.grey),
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
                          icon: const Icon(Icons.volume_up, size: 40),
                          color: Colors.grey[700],
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 70,
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _isAnswerVisible ? "Next" : "Answer",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
