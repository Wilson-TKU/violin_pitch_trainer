import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class QuestionRecord {
  final String noteName;
  final bool isCorrect;
  final int reactionTimeMs;
  QuestionRecord(this.noteName, this.isCorrect, this.reactionTimeMs);
}

class _ViolinAppState extends State<ViolinApp> with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  final Random _rng = Random();

  ViolinNote? _currentNote;
  bool _isPlaying = false;
  bool _isAnswerVisible = false;

  // --- 設定變數 ---
  double _referencePitch = 442.0;
  Set<MusicalKey> _selectedKeys = {MusicalKey.C_Major};
  bool _isMultiSelectMode = false;

  MusicalKey _currentQuestionKey = MusicalKey.C_Major;

  Set<ViolinPosition> _selectedPositions = {ViolinPosition.first};
  bool _isPositionMultiSelectMode = false;
  ViolinPosition _targetPosition = ViolinPosition.first;

  PracticeMode _practiceMode = PracticeMode.staffToFinger;
  RangeValues _rangePercent = const RangeValues(0.0, 1.0);

  // --- 遊戲化與報表變數 ---
  int _combo = 0;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.transparent;

  Timer? _flashcardTimer;
  double _timeLimitSetting = 1.5;
  double _timeLeft = 1.5;
  Stopwatch _reactionTimer = Stopwatch();

  // Session 管理
  double _questionsPerSessionDouble = 10.0;
  int get _questionsPerSession => _questionsPerSessionDouble.round();

  int _questionsDone = 0;
  List<QuestionRecord> _sessionResults = [];
  bool _isSessionActive = false;
  bool _isProcessingInput = false;

  // [NEW] Staff visibility controls
  bool _showClef = true;
  bool _showKeySignature = true;

  // [NEW] 靜音開關
  bool _isMuted = false;

  // [NEW] 應用程式前台狀態追蹤 (關鍵修正)
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashcardTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  // --- [NEW] Settings Persistence ---
  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('practiceMode', _practiceMode.name);
    await prefs.setDouble('referencePitch', _referencePitch);
    await prefs.setStringList(
        'selectedKeys', _selectedKeys.map((k) => k.name).toList());
    await prefs.setBool('isMultiSelectMode', _isMultiSelectMode);
    await prefs.setStringList(
        'selectedPositions', _selectedPositions.map((p) => p.name).toList());
    await prefs.setBool(
        'isPositionMultiSelectMode', _isPositionMultiSelectMode);
    await prefs.setDouble('rangePercentStart', _rangePercent.start);
    await prefs.setDouble('rangePercentEnd', _rangePercent.end);
    await prefs.setDouble(
        'questionsPerSessionDouble', _questionsPerSessionDouble);
    await prefs.setDouble('timeLimitSetting', _timeLimitSetting);
    await prefs.setBool('isMuted', _isMuted);
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _practiceMode = PracticeMode.values.firstWhere(
          (e) => e.name == prefs.getString('practiceMode'),
          orElse: () => PracticeMode.staffToFinger);

      _referencePitch = prefs.getDouble('referencePitch') ?? 442.0;

      List<String> keyNames = prefs.getStringList('selectedKeys') ?? [];
      if (keyNames.isNotEmpty) {
        _selectedKeys = keyNames
            .map((name) =>
                MusicalKey.values.firstWhere((k) => k.name == name))
            .toSet();
      } else {
        _selectedKeys = {MusicalKey.C_Major}; // Default
      }
      if (_selectedKeys.isEmpty) _selectedKeys = {MusicalKey.C_Major};
      _currentQuestionKey = _selectedKeys.first;

      _isMultiSelectMode = prefs.getBool('isMultiSelectMode') ?? false;

      List<String> posNames =
          prefs.getStringList('selectedPositions') ?? [];
      if (posNames.isNotEmpty) {
        _selectedPositions = posNames
            .map((name) =>
                ViolinPosition.values.firstWhere((p) => p.name == name))
            .toSet();
      } else {
        _selectedPositions = {ViolinPosition.first}; // Default
      }
      if (_selectedPositions.isEmpty)
        _selectedPositions = {ViolinPosition.first};

      _isPositionMultiSelectMode =
          prefs.getBool('isPositionMultiSelectMode') ?? false;

      final rangeStart = prefs.getDouble('rangePercentStart');
      final rangeEnd = prefs.getDouble('rangePercentEnd');
      if (rangeStart != null && rangeEnd != null) {
        _rangePercent = RangeValues(rangeStart, rangeEnd);
      } else {
        _resetRangeToFitPosition();
      }

      _questionsPerSessionDouble =
          prefs.getDouble('questionsPerSessionDouble') ?? 10.0;
      _timeLimitSetting = prefs.getDouble('timeLimitSetting') ?? 1.5;
      _isMuted = prefs.getBool('isMuted') ?? false;
    });

    _nextNote();
  }

  // [MODIFIED] 強化生命週期管理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台
      _isAppInForeground = true;

      // 如果是在 Session 中，且倒數計時器被暫停了，這裡可以選擇是否自動恢復
      // 目前策略：保持暫停，讓使用者看到當前畫面，避免一回來就突然嚇到
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 進入背景
      _isAppInForeground = false;

      // 強制停止所有活動
      _player.stop();
      _flashcardTimer?.cancel();
      _reactionTimer.stop();

      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _resetSessionState() {
    _flashcardTimer?.cancel();
    setState(() {
      _isSessionActive = false;
      _questionsDone = 0;
      _sessionResults.clear();
      _combo = 0;
      _feedbackMessage = null;
      _isAnswerVisible = false;
      _isProcessingInput = false;
    });
  }

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
    return (min: minP.clamp(0.0, 1.0), max: maxP.clamp(0.0, 1.0));
  }

  void _resetRangeToFitPosition() {
    var validRange = _getValidRangeForPositions();
    setState(() {
      _rangePercent = RangeValues(validRange.min, validRange.max);
    });
  }

  void _startSession() {
    _resetSessionState();
    setState(() {
      _isSessionActive = true;
    });
    _nextNote();
  }

  void _endSession() {
    setState(() {
      _isSessionActive = false;
      _flashcardTimer?.cancel();
    });
    _showReportDialog();
  }

  void _showReportDialog() {
    int total = _sessionResults.length;
    int correct = _sessionResults.where((r) => r.isCorrect).length;
    int score = total == 0 ? 0 : ((correct / total) * 100).round();

    Map<String, int> missCounts = {};
    for (var r in _sessionResults) {
      if (!r.isCorrect) {
        missCounts[r.noteName] = (missCounts[r.noteName] ?? 0) + 1;
      }
    }
    var sortedMisses = missCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("📝 練習報告 (Report)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "得分: $score 分",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: score >= 80 ? Colors.green : Colors.orange,
              ),
            ),
            Text("答對: $correct / $total"),
            const SizedBox(height: 10),
            const Text(
              "弱點分析 (最常錯):",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (sortedMisses.isEmpty)
              const Text("太棒了！全對！", style: TextStyle(color: Colors.green))
            else
              ...sortedMisses
                  .take(3)
                  .map((e) => Text("• ${e.key} (錯 ${e.value} 次)")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startSession();
            },
            child: const Text("再來一局"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text("關閉"),
          ),
        ],
      ),
    );
  }

  Future<void> _nextNote() async {
    // [FIX] 關鍵修正：如果 APP 在背景，直接終止執行，防止聲音或計時器啟動
    if (!_isAppInForeground) return;

    _flashcardTimer?.cancel();
    await _player.stop();

    if (_isSessionActive && _questionsDone >= _questionsPerSession) {
      _endSession();
      return;
    }

    setState(() {
      _feedbackMessage = null;
      _feedbackColor = Colors.transparent;
      _isAnswerVisible = false;
      _timeLeft = _timeLimitSetting;
      _isProcessingInput = false;
    });

    if (_selectedKeys.isEmpty || _selectedPositions.isEmpty) return;

    List<MusicalKey> availableKeys = _selectedKeys.toList();
    _currentQuestionKey = availableKeys[_rng.nextInt(availableKeys.length)];

    List<ViolinNote> keyValidNotes = allNotes.where((note) {
      return ViolinLogic.isNoteInKey(note, _currentQuestionKey);
    }).toList();

    List<ViolinNote> positionValidNotes = keyValidNotes.where((note) {
      for (var pos in _selectedPositions) {
        if (ViolinLogic.isNoteInPosition(note, pos)) return true;
      }
      return false;
    }).toList();

    if (positionValidNotes.isEmpty) return;

    int globalTotal = allNotes.length;
    int minIndex = (_rangePercent.start * (globalTotal - 1)).round();
    int maxIndex = (_rangePercent.end * (globalTotal - 1)).round();

    List<ViolinNote> rangeFilteredNotes = positionValidNotes.where((note) {
      int idx = allNotes.indexOf(note);
      return idx >= minIndex && idx <= maxIndex;
    }).toList();

    if (rangeFilteredNotes.isEmpty) rangeFilteredNotes = positionValidNotes;

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
    });

    if (!_isMuted) {
      // 再次檢查 (避免 async gap 期間切到背景)
      if (!_isAppInForeground) {
        setState(() => _isPlaying = false);
        return;
      }

      double adjustedFrequency = note.frequency * (_referencePitch / 440.0);
      final Uint8List wavBytes = ToneGenerator.generateSineWave(
        frequency: adjustedFrequency,
        durationMs: 800,
        sampleRate: 44100,
      );

      try {
        await _player.play(BytesSource(wavBytes));
      } catch (e) {
        debugPrint("Audio Error: $e");
      }
    }

    if (_isGameMode()) {
      _startTimer();
      _reactionTimer.reset();
      _reactionTimer.start();
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted && _currentNote == note) {
      setState(() => _isPlaying = false);
    }
  }

  void _startTimer() {
    _flashcardTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      // 安全檢查
      if (!_isAppInForeground) {
        timer.cancel();
        return;
      }

      setState(() {
        _timeLeft -= 0.1;
        if (_timeLeft <= 0) {
          _handleGameAnswer(false);
          timer.cancel();
        }
      });
    });
  }

  void _checkSolfegeInput(String inputSolfege) {
    if (_isProcessingInput || _currentNote == null) return;

    bool isCorrect = _currentNote!.solfege == inputSolfege;
    _handleGameAnswer(isCorrect);
  }

  void _handleGameAnswer(bool isCorrect) {
    _flashcardTimer?.cancel();
    _reactionTimer.stop();

    setState(() {
      _isProcessingInput = true;
    });

    if (_isSessionActive) {
      _sessionResults.add(
        QuestionRecord(
          _currentNote
                  ?.getDisplayName(_currentQuestionKey)
                  .replaceAll('\n', ' ') ??
              "?",
          isCorrect,
          _reactionTimer.elapsedMilliseconds,
        ),
      );
      _questionsDone++;
    }

    setState(() {
      if (isCorrect) {
        _combo++;
        _feedbackMessage = "Correct!";
        _feedbackColor = Colors.green;
        Future.delayed(const Duration(milliseconds: 200), _nextNote);
      } else {
        _combo = 0;
        _feedbackMessage = "Wrong! It's ${_currentNote?.solfege}";
        _feedbackColor = Colors.red;
        _isAnswerVisible = true;
        Future.delayed(const Duration(milliseconds: 1200), _nextNote);
      }
    });
  }

  void _revealAnswer() {
    setState(() {
      _isAnswerVisible = true;
    });
  }

  String _getModeName(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.staffToFinger:
        return "看譜 -> 找指位";
      case PracticeMode.fingerToStaff:
        return "看指位 -> 猜音";
      case PracticeMode.earTraining:
        return "聽音 -> 辨音高";
      case PracticeMode.staffToSolfege:
        return "極速視譜 (Flashcard)";
      case PracticeMode.positionToSolfege:
        return "指位 -> 唱名";
    }
  }

  bool _isGameMode() {
    return _practiceMode == PracticeMode.staffToSolfege ||
        _practiceMode == PracticeMode.positionToSolfege;
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Use a list of bools to manage the expansion state of the panels.
        List<bool> _settingsPanelExpanded = [
          false, // 1. Practice Mode
          true, // 2. Keys (Expanded by default)
          false, // 3. Positions
          false, // 4. Note Range
          false, // 5. Questions per Session
          false, // 6. Reference Pitch
        ];

        // Helper to build a summary string for the selected keys
        String getSelectedKeysSummary() {
          if (_selectedKeys.isEmpty) return "None";
          if (_selectedKeys.length > 2)
            return "${_selectedKeys.first.label}, ... (${_selectedKeys.length})";
          return _selectedKeys.map((k) => k.label).join(', ');
        }

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            var validRange = _getValidRangeForPositions();
            int total = allNotes.length;
            int sIdx = (_rangePercent.start * (total - 1)).round();
            int eIdx = (_rangePercent.end * (total - 1)).round();
            ViolinNote sNote = allNotes[sIdx];
            ViolinNote eNote = allNotes[eIdx];
            String startStr =
                sNote.getDisplayName(_selectedKeys.first).replaceAll('\n', ' ');
            String endStr =
                eNote.getDisplayName(_selectedKeys.first).replaceAll('\n', ' ');

            return Container(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "設定 (Settings)",
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ExpansionPanelList(
                        expansionCallback: (int index, bool isExpanded) {
                          setModalState(() {
                            _settingsPanelExpanded[index] =
                                !_settingsPanelExpanded[index];
                          });
                        },
                        children: [
                          // 1. Practice Mode
                          ExpansionPanel(
                            canTapOnHeader: true,
                            headerBuilder: (context, isExpanded) {
                              return ListTile(
                                title: const Text("1. 練習模式"),
                                subtitle: Text(_getModeName(_practiceMode)),
                              );
                            },
                            body: Padding(
                              padding: const EdgeInsets.all(15.0),
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: PracticeMode.values.map((mode) {
                                  return ChoiceChip(
                                    label: Text(_getModeName(mode)),
                                    selected: _practiceMode == mode,
                                    onSelected: (val) {
                                      if (val) {
                                        _resetSessionState();
                                        setModalState(
                                            () => _practiceMode = mode);
                                        setState(() {
                                          _practiceMode = mode;
                                          _saveSettings();
                                          _nextNote();
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            isExpanded: _settingsPanelExpanded[0],
                          ),
                          // 2. Keys
                          ExpansionPanel(
                            canTapOnHeader: true,
                            headerBuilder: (context, isExpanded) {
                              return ListTile(
                                title: const Text("2. 調性"),
                                subtitle: Text(getSelectedKeysSummary()),
                              );
                            },
                            body: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(""), // Placeholder
                                      Row(
                                        children: [
                                          const Text("多選: "),
                                          Switch(
                                            value: _isMultiSelectMode,
                                            onChanged: (val) {
                                              setModalState(() =>
                                                  _isMultiSelectMode = val);
                                              setState(() {
                                                _isMultiSelectMode = val;
                                                _saveSettings();
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isMultiSelectMode)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          right: 15.0, bottom: 10),
                                      child: TextButton(
                                        onPressed: () {
                                          setModalState(() {
                                            if (_selectedKeys.length ==
                                                MusicalKey.values.length) {
                                              _selectedKeys = {
                                                MusicalKey.C_Major
                                              };
                                            } else {
                                              _selectedKeys =
                                                  Set.from(MusicalKey.values);
                                            }
                                          });
                                          setState(() {
                                            _saveSettings();
                                            _nextNote();
                                          });
                                        },
                                        child: const Text("全選/重置"),
                                      ),
                                    ),
                                  ),
                                Center(
                                  child: _buildKeyButton(
                                      MusicalKey.C_Major, setModalState),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text("b"),
                                          _buildKeyButton(
                                              MusicalKey.F_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.Bb_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.Eb_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.Ab_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.Db_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.Gb_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.Cb_Major,
                                              setModalState),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text("#"),
                                          _buildKeyButton(
                                              MusicalKey.G_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.D_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.A_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.E_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.B_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.F_Sharp_Major,
                                              setModalState),
                                          _buildKeyButton(
                                              MusicalKey.C_Sharp_Major,
                                              setModalState),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                              ],
                            ),
                            isExpanded: _settingsPanelExpanded[1],
                          ),
                          // 3. Positions
                          ExpansionPanel(
                            canTapOnHeader: true,
                            headerBuilder: (context, isExpanded) {
                              return ListTile(
                                title: const Text("3. 把位"),
                                subtitle: Text(_selectedPositions
                                    .map((p) => p.label.split(' ')[0])
                                    .join(', ')),
                              );
                            },
                            body: Padding(
                              padding: const EdgeInsets.all(15.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(""),
                                      Row(
                                        children: [
                                          const Text("多選: "),
                                          Switch(
                                            value: _isPositionMultiSelectMode,
                                            onChanged: (val) {
                                              setModalState(() =>
                                                  _isPositionMultiSelectMode =
                                                      val);
                                              setState(() {
                                                _isPositionMultiSelectMode =
                                                    val;
                                                if (!val &&
                                                    _selectedPositions.length >
                                                        1) {
                                                  _selectedPositions = {
                                                    _selectedPositions.first
                                                  };
                                                }
                                                _resetRangeToFitPosition();
                                                _saveSettings();
                                                _nextNote();
                                              });
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
                                          label: Text("First")),
                                      ButtonSegment(
                                          value: ViolinPosition.third,
                                          label: Text("Third")),
                                    ],
                                    selected: _selectedPositions,
                                    multiSelectionEnabled:
                                        _isPositionMultiSelectMode,
                                    onSelectionChanged: (newValues) {
                                      setModalState(() {
                                        if (_isPositionMultiSelectMode) {
                                          if (newValues.isEmpty) return;
                                          _selectedPositions = newValues;
                                        } else {
                                          if (newValues.isNotEmpty)
                                            _selectedPositions = newValues;
                                        }
                                        _resetRangeToFitPosition();
                                      });
                                      setState(() {
                                        _saveSettings();
                                        _nextNote();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            isExpanded: _settingsPanelExpanded[2],
                          ),
                          // 4. Note Range
                          ExpansionPanel(
                            canTapOnHeader: true,
                            headerBuilder: (context, isExpanded) {
                              return ListTile(
                                title: const Text("4. 音域"),
                                subtitle: Text("$startStr ~ $endStr"),
                              );
                            },
                            body: Padding(
                              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                              child: RangeSlider(
                                values: _rangePercent,
                                min: 0.0,
                                max: 1.0,
                                divisions: 40,
                                onChanged: (RangeValues values) {
                                  double clampedStart = values.start;
                                  double clampedEnd = values.end;
                                  if (clampedStart < validRange.min)
                                    clampedStart = validRange.min;
                                  if (clampedEnd > validRange.max)
                                    clampedEnd = validRange.max;
                                  if (clampedStart > clampedEnd)
                                    clampedStart = clampedEnd;
                                  setModalState(() => _rangePercent =
                                      RangeValues(clampedStart, clampedEnd));
                                  setState(() {
                                    _saveSettings();
                                  });
                                },
                              ),
                            ),
                            isExpanded: _settingsPanelExpanded[3],
                          ),
                          // 5. Questions Per Session
                          ExpansionPanel(
                            canTapOnHeader: true,
                            headerBuilder: (context, isExpanded) {
                              return ListTile(
                                title: const Text("5. 每回合題數"),
                                subtitle: Text("$_questionsPerSession 題"),
                              );
                            },
                            body: Padding(
                              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                              child: Slider(
                                value: _questionsPerSessionDouble,
                                min: 10,
                                max: 100,
                                divisions: 9,
                                label: "$_questionsPerSession",
                                onChanged: (val) {
                                  setModalState(
                                      () => _questionsPerSessionDouble = val);
                                  setState(() {
                                    _saveSettings();
                                  });
                                },
                              ),
                            ),
                            isExpanded: _settingsPanelExpanded[4],
                          ),
                          // 6. Reference Pitch
                          ExpansionPanel(
                            canTapOnHeader: true,
                            headerBuilder: (context, isExpanded) {
                              return ListTile(
                                title: const Text("6. 基準音"),
                                subtitle: Text("${_referencePitch.toInt()} Hz"),
                              );
                            },
                            body: Padding(
                              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                              child: SegmentedButton<double>(
                                segments: const [
                                  ButtonSegment(
                                      value: 440.0, label: Text("440Hz")),
                                  ButtonSegment(
                                      value: 442.0, label: Text("442Hz")),
                                ],
                                selected: {_referencePitch},
                                onSelectionChanged: (newVal) {
                                  setModalState(
                                      () => _referencePitch = newVal.first);
                                  setState(() {
                                    _saveSettings();
                                  });
                                },
                              ),
                            ),
                            isExpanded: _settingsPanelExpanded[5],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("完成"),
                      ),
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
        setState(() {
          _saveSettings();
          _nextNote();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        height: 45,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              key.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.blue[800] : Colors.black87,
              ),
            ),
            CustomPaint(
              size: const Size(50, 15),
              painter: KeySignaturePainter(accidentals: key.accidentals),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolfegeKeypad() {
    final accidentals = ['Do#', 'Re#', 'Fa#', 'Sol#', 'La#'];
    final naturals = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: accidentals
                .map(
                  (note) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () => _checkSolfegeInput(note),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            note,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: naturals
                .map(
                  (note) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        onPressed: () => _checkSolfegeInput(note),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            note,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showFingerboardHint = false;
    bool showStaff = true;

    switch (_practiceMode) {
      case PracticeMode.staffToFinger:
        showStaff = true;
        showFingerboardHint = !_isAnswerVisible;
        break;
      case PracticeMode.fingerToStaff:
        showStaff = _isAnswerVisible;
        showFingerboardHint = false;
        break;
      case PracticeMode.earTraining:
        showStaff = _isAnswerVisible;
        showFingerboardHint = !_isAnswerVisible;
        break;
      case PracticeMode.staffToSolfege:
        showStaff = true;
        showFingerboardHint = true;
        break;
      case PracticeMode.positionToSolfege:
        showStaff = false;
        showFingerboardHint = false;
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _isSessionActive
            ? Text("Session: $_questionsDone / $_questionsPerSession")
            : Text("Violin Trainer"),
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
            onPressed: () {
              setState(() {
                _isMuted = !_isMuted;
              });
              _saveSettings();
            },
          ),
          if (!_isSessionActive && _isGameMode())
            TextButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text("Start Session"),
              onPressed: _startSession,
            ),
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
                      targetNote:
                          (_practiceMode == PracticeMode.fingerToStaff ||
                              _practiceMode == PracticeMode.positionToSolfege ||
                              _isAnswerVisible)
                          ? _currentNote
                          : null,
                      currentKey: _currentQuestionKey,
                      currentPosition: _targetPosition,
                    ),
                  ),
                  if (showFingerboardHint)
                    const Center(
                      child: Text(
                        "?",
                        style: TextStyle(fontSize: 80, color: Colors.white24),
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
                // 1. 頂部控制區
                if (_isGameMode())
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    color: Colors.grey[100],
                    child: Row(
                      children: [
                        const Icon(Icons.timer, size: 16),
                        const SizedBox(width: 5),
                        Text("${_timeLimitSetting}s"),
                        Expanded(
                          child: Slider(
                            value: _timeLimitSetting,
                            min: 0.5,
                            max: 5.0,
                            divisions: 9,
                            label: "${_timeLimitSetting}s",
                            onChanged: (val) {
                              setState(() => _timeLimitSetting = val);
                              _saveSettings();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. 五線譜區域
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isGameMode())
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: _timeLeft / _timeLimitSetting,
                              color: _timeLeft > 0.5 ? Colors.blue : Colors.red,
                              minHeight: 4,
                            ),
                          ),

                        // Scrollable Staff
                        CustomPaint(
                          size: Size.infinite,
                          painter: StaffPainter(
                            noteIndex:
                                showStaff ? _currentNote?.staffIndex : null,
                            keySignature: _currentQuestionKey,
                            showClef: _showClef,
                            showKeySignature: _showKeySignature,
                          ),
                        ),

                        if (!showStaff)
                          const Icon(
                            Icons.visibility_off,
                            size: 50,
                            color: Colors.grey,
                          ),

                        // Feedback message overlay
                        if (_feedbackMessage != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _feedbackColor.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _feedbackMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                        // [NEW] Overlay Toggle Buttons
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _showClef
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey[600],
                                  ),
                                  tooltip: "顯示/隱藏譜號",
                                  onPressed: () {
                                    setState(() {
                                      _showClef = !_showClef;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    _showKeySignature
                                        ? Icons.vpn_key
                                        : Icons.vpn_key_off,
                                    color: Colors.grey[600],
                                  ),
                                  tooltip: "顯示/隱藏調號",
                                  onPressed: () {
                                    setState(() {
                                      _showKeySignature = !_showKeySignature;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // 3. 操作區域
                Expanded(
                  flex: 6,
                  child: Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${_getModeName(_practiceMode)} - ${_currentQuestionKey.label}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // --- 核心分歧點 ---
                        if (_isGameMode()) ...[
                          Expanded(child: _buildSolfegeKeypad()),

                          // 固定高度區域
                          SizedBox(
                            height: 60,
                            width: double.infinity,
                            child: _isAnswerVisible
                                ? Center(
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 45,
                                      child: ElevatedButton(
                                        onPressed: _nextNote,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                        ),
                                        child: const Text(
                                          "Next Note",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                        ] else ...[
                          // --- 舊模式 UI ---
                          if (_isAnswerVisible) ...[
                            Text(
                              _currentNote
                                      ?.getDisplayName(_currentQuestionKey)
                                      .split('\n')[0] ??
                                  "",
                              style: const TextStyle(
                                fontSize: 50,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              _currentNote?.solfege ?? "",
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.black54,
                              ),
                            ),
                          ] else
                            const Text(
                              "?",
                              style: TextStyle(
                                fontSize: 70,
                                color: Colors.grey,
                              ),
                            ),

                          const Spacer(),

                          IconButton(
                            onPressed: () async {
                              if (_currentNote != null) {
                                if (_isMuted) return;

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
                          const SizedBox(height: 10),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _isAnswerVisible ? "Next" : "Answer",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
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
