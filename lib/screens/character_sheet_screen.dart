import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/models/chronicle.dart';
import 'package:vtm_helper/services/storage_service.dart';
import 'package:vtm_helper/services/drive_sync_service.dart';
import 'package:vtm_helper/services/character_diff.dart';
import 'package:vtm_helper/widgets/sections/header_section.dart';
import 'package:vtm_helper/widgets/sections/attributes_section.dart';
import 'package:vtm_helper/widgets/sections/abilities_section.dart';
import 'package:vtm_helper/widgets/sections/advantages_section.dart';
import 'package:vtm_helper/widgets/sections/merits_flaws_section.dart';
import 'package:vtm_helper/widgets/sections/humanity_section.dart';
import 'package:vtm_helper/widgets/sections/willpower_section.dart';
import 'package:vtm_helper/widgets/sections/blood_pool_section.dart';
import 'package:vtm_helper/widgets/sections/experience_section.dart';
import 'package:vtm_helper/widgets/sections/health_section.dart';
import 'package:vtm_helper/widgets/sections/notes_section.dart';
import 'package:vtm_helper/screens/sheet_theme_editor_screen.dart';

class CharacterSheetScreen extends StatefulWidget {
  final Character character;
  const CharacterSheetScreen({super.key, required this.character});

  @override
  State<CharacterSheetScreen> createState() => _CharacterSheetScreenState();
}

class _CharacterSheetScreenState extends State<CharacterSheetScreen> {
  late Character _character;
  final StorageService _storage = StorageService();
  bool _isEditing = false; // по умолчанию режим просмотра
  List<SheetTheme> _customThemes = [];
  List<Chronicle> _chronicles = [];
  Character? _remoteSheet;
  List<String> _remoteChanges = [];
  bool _checkingDrive = false;
  bool _driveCheckFailed = false;
  Future<void> _saveInFlight = Future.value();
  Timer? _notesDebounce;
  bool _pendingNotesSave = false;

  @override
  void initState() {
    super.initState();
    _character = widget.character;
    _loadCustomThemes();
    _loadChronicles().then((_) => _checkDriveUpdate());
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    if (_pendingNotesSave) {
      _saveCharacter();
    }
    super.dispose();
  }

  bool get _driveHasUpdate {
    final remote = _remoteSheet;
    if (remote == null) return false;
    if (remote.updatedAt > _character.updatedAt) return true;
    return _remoteChanges.isNotEmpty;
  }

  Future<void> _loadChronicles() async {
    final list = await _storage.loadChronicles();
    if (!mounted) return;
    setState(() => _chronicles = list);
  }

  Chronicle? get _assignedChronicle {
    final id = _character.chronicleId;
    if (id == null) return null;
    for (final c in _chronicles) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool get _storytellerMode =>
      _assignedChronicle?.role == ChronicleRole.storyteller;

  Future<void> _loadCustomThemes() async {
    final list = await _storage.loadCustomThemes();
    if (!mounted) return;
    setState(() {
      _customThemes = list;
    });
  }

  Future<void> _saveCharacter() {
    _saveInFlight = _saveInFlight.then((_) async {
      _character.updatedAt = DateTime.now().millisecondsSinceEpoch;
      await _storage.updateCharacter(_character);
    });
    return _saveInFlight;
  }

  // Общие методы для обновления разных частей модели
  void _updateHeader({
    String? name,
    String? player,
    String? chronicle,
    String? nature,
    String? mask,
    String? generation,
    String? haven,
    String? clan,
    String? concept,
  }) {
    setState(() {
      if (name != null) _character.name = name;
      if (player != null) _character.player = player;
      if (chronicle != null) _character.chronicle = chronicle;
      if (nature != null) _character.nature = nature;
      if (mask != null) _character.mask = mask;
      if (generation != null) _character.generation = generation;
      if (haven != null) _character.haven = haven;
      if (clan != null) _character.clan = clan;
      if (concept != null) _character.concept = concept;
    });
    _saveCharacter();
  }

  void _updateAttribute(String name, int value) {
    setState(() {
      _character.attributes[name] = value;
    });
    _saveCharacter();
  }

  void _updateAbility(String name, int value) {
    setState(() {
      _character.abilities[name] = value;
    });
    _saveCharacter();
  }

  void _updateAttributeSpecialty(String name, String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        _character.attributeSpecialties.remove(name);
      } else {
        _character.attributeSpecialties[name] = value;
      }
    });
    _saveCharacter();
  }

  void _updateAbilitySpecialty(String name, String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        _character.abilitySpecialties.remove(name);
      } else {
        _character.abilitySpecialties[name] = value;
      }
    });
    _saveCharacter();
  }

  void _addAbility(AbilityCategory category, String name) {
    setState(() {
      _character.abilities[name] = 0;
      switch (category) {
        case AbilityCategory.talent:
          _character.extraTalents.add(name);
          break;
        case AbilityCategory.skill:
          _character.extraSkills.add(name);
          break;
        case AbilityCategory.knowledge:
          _character.extraKnowledges.add(name);
          break;
      }
    });
    _saveCharacter();
  }

  void _removeAbility(AbilityCategory category, String name) {
    setState(() {
      _character.abilities.remove(name);
      _character.abilitySpecialties.remove(name);
      _character.customAbilityDescriptions.remove(name);
      switch (category) {
        case AbilityCategory.talent:
          _character.extraTalents.remove(name);
          break;
        case AbilityCategory.skill:
          _character.extraSkills.remove(name);
          break;
        case AbilityCategory.knowledge:
          _character.extraKnowledges.remove(name);
          break;
      }
    });
    _saveCharacter();
  }

  void _updateCustomAbilityDescription(String name, String? description) {
    setState(() {
      if (description == null || description.isEmpty) {
        _character.customAbilityDescriptions.remove(name);
      } else {
        _character.customAbilityDescriptions[name] = description;
      }
    });
    _saveCharacter();
  }

  void _updateDisciplines(List<ExpandableItem> newList) {
    setState(() {
      _character.disciplines = newList;
    });
    _saveCharacter();
  }

  void _updateBackgrounds(List<ExpandableItem> newList) {
    setState(() {
      _character.backgrounds = newList;
    });
    _saveCharacter();
  }

  void _updateMerits(List<ExpandableItem> newList) {
    setState(() {
      _character.merits = newList;
    });
    _saveCharacter();
  }

  void _updateFlaws(List<ExpandableItem> newList) {
    setState(() {
      _character.flaws = newList;
    });
    _saveCharacter();
  }

  void _updateVirtue(String name, int value) {
    setState(() {
      _character.virtues[name] = value;
    });
    _saveCharacter();
  }

  void _updateHumanity(int value) {
    setState(() {
      _character.humanity = value;
    });
    _saveCharacter();
  }

  void _updateWillpower(int permanent, int current) {
    setState(() {
      _character.willpowerPermanent = permanent;
      _character.willpowerCurrent = current;
    });
    _saveCharacter();
  }

  void _updateBloodPool(int value) {
    setState(() {
      _character.bloodPool = value;
    });
    _saveCharacter();
  }

  void _updateExperience(int value) {
    setState(() {
      _character.experience = value;
    });
    _saveCharacter();
  }

  void _updateSheetTheme(String themeId) {
    setState(() {
      _character.sheetThemeId = themeId;
    });
    _saveCharacter();
  }

  Widget _themeLeading(SheetTheme theme) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.background,
        border: Border.all(color: theme.border, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: theme.accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final current = _character.sheetThemeId;
              return SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Тема листа',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Кланы'),
                    ),
                    ...SheetTheme.presets.map((theme) {
                      final selected = theme.id == current;
                      return ListTile(
                        leading: _themeLeading(theme),
                        title: Text(theme.name),
                        trailing: selected
                            ? const Icon(Icons.check, color: Colors.deepPurpleAccent)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _updateSheetTheme(theme.id);
                        },
                      );
                    }),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Expanded(child: Text('Свои темы')),
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _createCustomTheme();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Создать'),
                          ),
                        ],
                      ),
                    ),
                    if (_customThemes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Пока нет своих тем'),
                      ),
                    ..._customThemes.map((theme) {
                      final selected = theme.id == current;
                      return ListTile(
                        leading: _themeLeading(theme),
                        title: Text(theme.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected)
                              const Icon(Icons.check, color: Colors.deepPurpleAccent),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Изменить',
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _editCustomTheme(theme);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Удалить',
                              onPressed: () async {
                                await _deleteCustomTheme(theme.id);
                                setSheet(() {});
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _updateSheetTheme(theme.id);
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _createCustomTheme() async {
    final base = SheetTheme.byId(_character.sheetThemeId, custom: _customThemes);
    final created = await Navigator.push<SheetTheme>(
      context,
      MaterialPageRoute(
        builder: (_) => SheetThemeEditorScreen(
          initial: base.copyWith(
            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
            name: 'Своя тема',
          ),
          isNew: true,
        ),
      ),
    );
    if (created == null) return;
    final list = List<SheetTheme>.from(_customThemes)..add(created);
    await _storage.saveCustomThemes(list);
    if (!mounted) return;
    setState(() {
      _customThemes = list;
      _character.sheetThemeId = created.id;
    });
    await _saveCharacter();
  }

  Future<void> _editCustomTheme(SheetTheme theme) async {
    final edited = await Navigator.push<SheetTheme>(
      context,
      MaterialPageRoute(
        builder: (_) => SheetThemeEditorScreen(initial: theme, isNew: false),
      ),
    );
    if (edited == null) return;
    final list = _customThemes
        .map((t) => t.id == theme.id ? edited.copyWith(id: theme.id) : t)
        .toList();
    await _storage.saveCustomThemes(list);
    if (!mounted) return;
    setState(() {
      _customThemes = list;
      if (_character.sheetThemeId == theme.id) {
        _character.sheetThemeId = theme.id;
      }
    });
    await _saveCharacter();
  }

  Future<void> _deleteCustomTheme(String id) async {
    final list = _customThemes.where((t) => t.id != id).toList();
    await _storage.saveCustomThemes(list);
    setState(() {
      _customThemes = list;
      if (_character.sheetThemeId == id) {
        _character.sheetThemeId = SheetTheme.defaultId;
      }
    });
    await _saveCharacter();
  }


  String _stamp(int ms) {
    if (ms <= 0) return 'нет даты';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _syncUploadThis() async {
    final chron = _assignedChronicle;
    try {
      _character.updatedAt = DateTime.now().millisecondsSinceEpoch;
      if (chron == null || chron.driveFolderId == null) {
        await DriveSyncService.instance.uploadStandaloneCharacter(_character);
      } else {
        await DriveSyncService.instance.uploadOneCharacter(
          chronicle: chron,
          character: _character,
        );
      }
      await _storage.addSyncLog(
        action: 'Отправка с листа',
        characterName: _character.name,
        detail: _stamp(_character.updatedAt),
      );
      await _saveCharacter();
      if (!mounted) return;
      setState(() {
        _remoteSheet = null;
        _remoteChanges = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отправлено на Диск')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить: $e')),
      );
    }
  }


  Future<void> _checkDriveUpdate() async {
    final chron = _assignedChronicle;
    if (_checkingDrive) return;
    _checkingDrive = true;
    try {
      final Character? remote;
      if (chron == null || chron.driveFolderId == null) {
        remote = await DriveSyncService.instance.downloadStandaloneCharacter(
          _character.id,
        );
      } else {
        remote = await DriveSyncService.instance.downloadOneCharacter(
          chronicle: chron,
          characterId: _character.id,
        );
      }
      if (!mounted) return;
      if (remote == null) {
        setState(() {
          _remoteSheet = null;
          _remoteChanges = [];
          _driveCheckFailed = false;
        });
        return;
      }
      remote.chronicleId = chron?.id;
      _mergeIncomingPrivateNotes(remote);
      final changes = CharacterDiff.describe(_character, remote);
      setState(() {
        _remoteSheet = remote;
        _remoteChanges = changes;
        _driveCheckFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _driveCheckFailed = true);
    } finally {
      _checkingDrive = false;
    }
  }

  Future<void> _syncDownloadThis() async {
    await _checkDriveUpdate();
    final remote = _remoteSheet;
    if (remote == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _driveCheckFailed
                ? 'Не удалось проверить Диск (сеть или VPN)'
                : 'Локальная версия актуальна. На Диске нет более новой копии этого листа.',
          ),
        ),
      );
      return;
    }
    if (remote.updatedAt <= _character.updatedAt && _remoteChanges.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Локальная версия актуальна')),
      );
      return;
    }
    final changes = _remoteChanges.isEmpty
        ? CharacterDiff.describe(_character, remote)
        : _remoteChanges;
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Обновление с Диска'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Диск: ${_stamp(remote.updatedAt)}\n'
                  'Локально: ${_stamp(_character.updatedAt)}',
                ),
                const SizedBox(height: 12),
                if (changes.isEmpty)
                  const Text('Содержимое совпадает, отличается только время сохранения.')
                else
                  ...changes.map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $line'),
                      )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (go != true) return;
    _mergeIncomingPrivateNotes(remote);
    setState(() {
      _character = remote;
      _remoteSheet = null;
      _remoteChanges = [];
    });
    await _saveCharacter();
    await _storage.addSyncLog(
      action: 'Скачивание с листа',
      characterName: remote.name,
      detail: changes.isEmpty ? _stamp(remote.updatedAt) : changes.join('; '),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Применено с Диска')),
    );
  }

  Future<void> _assignChronicle() async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Хроника этого листа',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('Без хроники'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ..._chronicles.map(
                (c) => ListTile(
                  title: Text(c.name),
                  subtitle: Text(
                    c.role == ChronicleRole.storyteller
                        ? 'Вы — рассказчик'
                        : 'Вы — игрок',
                  ),
                  selected: _character.chronicleId == c.id,
                  onTap: () => Navigator.pop(ctx, c.id),
                ),
              ),
              if (_chronicles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Создайте хронику на главном экране'),
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null) return;
    final previous = _assignedChronicle;
    setState(() {
      _character.chronicleId = chosen.isEmpty ? null : chosen;
    });
    await _saveCharacter();
    Chronicle? next;
    if (chosen.isNotEmpty) {
      for (final c in _chronicles) {
        if (c.id == chosen) {
          next = c;
          break;
        }
      }
    }
    try {
      await DriveSyncService.instance.relocateCharacter(
        character: _character,
        from: previous,
        to: next,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Локально перенесено, Диск: $e')),
      );
    }
  }

  void _mergeIncomingPrivateNotes(Character incoming) {
    if (!_storytellerMode) {
      incoming.storytellerPrivateNotes = '';
      return;
    }
    if (incoming.storytellerPrivateNotes.isEmpty &&
        _character.storytellerPrivateNotes.isNotEmpty) {
      incoming.storytellerPrivateNotes = _character.storytellerPrivateNotes;
    }
  }

  void _updateNotes(String shared, String private) {
    _character.storytellerNotes = shared;
    _character.storytellerPrivateNotes = private;
    _pendingNotesSave = true;
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 400), () {
      _pendingNotesSave = false;
      _saveCharacter();
    });
  }

  void _updateHealth(List<InjuryLevel> newLevels) {
    setState(() {
      _character.healthLevels = newLevels;
    });
    _saveCharacter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_character.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: _assignedChronicle?.driveFolderId == null
                ? 'Сохранить на Диск (личные листы)'
                : 'Отправить на Диск',
            onPressed: _syncUploadThis,
          ),
          IconButton(
            icon: Icon(
              _driveHasUpdate
                  ? Icons.cloud_download
                  : Icons.cloud_download_outlined,
              color: _driveHasUpdate ? Colors.lightBlueAccent : null,
            ),
            tooltip: _driveHasUpdate
                ? 'На Диске есть новая версия'
                : 'Скачать с Диска',
            onPressed: _syncDownloadThis,
          ),
          IconButton(
            icon: Icon(
              _storytellerMode ? Icons.menu_book : Icons.menu_book_outlined,
            ),
            tooltip: _assignedChronicle == null
                ? 'Привязать к хронике'
                : '${_assignedChronicle!.name} (${_storytellerMode ? "рассказчик" : "игрок"})',
            onPressed: _assignChronicle,
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Тема листа',
            onPressed: _showThemePicker,
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.edit_off : Icons.edit),
            tooltip: _isEditing
                ? 'Выключить редактирование'
                : 'Включить редактирование',
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Только при очень узкой ширине; на телефонах оставляем 3 колонки листа
          final bool useVerticalLayout = constraints.maxWidth < 360;
          final sheetTheme = SheetTheme.byId(_character.sheetThemeId, custom: _customThemes);

          return SheetThemeScope(
            theme: sheetTheme,
            child: Container(
            decoration: BoxDecoration(
              color: sheetTheme.background,
              border: Border.all(color: sheetTheme.border, width: 4),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: sheetTheme.background.withOpacity(0.9),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            margin: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeaderSection(
                      character: _character,
                      onChanged: _updateHeader,
                      useVerticalLayout: useVerticalLayout,
                      isEditing: _isEditing,
                    ),
                    const SizedBox(height: 24),
                    AttributesSection(
                      attributes: _character.attributes,
                      specialties: _character.attributeSpecialties,
                      onChanged: _updateAttribute,
                      onSpecialtyChanged: _updateAttributeSpecialty,
                      useVerticalLayout: useVerticalLayout,
                      isEditing: _isEditing,
                    ),
                    const SizedBox(height: 32),
                    Divider(color: sheetTheme.accent, thickness: 2),
                    const SizedBox(height: 16),
                    AbilitiesSection(
                      abilities: _character.abilities,
                      specialties: _character.abilitySpecialties,
                      extraTalents: _character.extraTalents,
                      extraSkills: _character.extraSkills,
                      extraKnowledges: _character.extraKnowledges,
                      customDescriptions: _character.customAbilityDescriptions,
                      onChanged: _updateAbility,
                      onSpecialtyChanged: _updateAbilitySpecialty,
                      onCustomDescriptionChanged: _updateCustomAbilityDescription,
                      onAbilityAdded: _addAbility,
                      onAbilityRemoved: _removeAbility,
                      useVerticalLayout: useVerticalLayout,
                      isEditing: _isEditing,
                    ),
                    const SizedBox(height: 32),
                    Divider(color: sheetTheme.accent, thickness: 2),
                    const SizedBox(height: 16),
                    AdvantagesSection(
                      disciplines: _character.disciplines,
                      backgrounds: _character.backgrounds,
                      virtues: _character.virtues,
                      onDisciplinesChanged: _updateDisciplines,
                      onBackgroundsChanged: _updateBackgrounds,
                      onVirtueChanged: _updateVirtue,
                      useVerticalLayout: useVerticalLayout,
                      isEditing: _isEditing,
                    ),
                    const SizedBox(height: 32),
                    Divider(color: sheetTheme.accent, thickness: 2),
                    const SizedBox(height: 16),
                    MeritsFlawsSection(
                      merits: _character.merits,
                      flaws: _character.flaws,
                      onMeritsChanged: _updateMerits,
                      onFlawsChanged: _updateFlaws,
                      useVerticalLayout: useVerticalLayout,
                      isEditing: _isEditing,
                    ),
                    const SizedBox(height: 32),
                    Divider(color: sheetTheme.accent, thickness: 2),
                    const SizedBox(height: 16),
                    HumanitySection(
                      value: _character.humanity,
                      onChanged: _updateHumanity,
                    ),
                    const SizedBox(height: 24),
                    WillpowerSection(
                      permanent: _character.willpowerPermanent,
                      current: _character.willpowerCurrent,
                      onChanged: _updateWillpower,
                    ),
                    const SizedBox(height: 24),
                    BloodPoolSection(
                      value: _character.bloodPool,
                      generation: _character.generation,
                      onChanged: _updateBloodPool,
                    ),
                    const SizedBox(height: 24),
                    HealthSection(
                      healthLevels: _character.healthLevels,
                      onChanged: _updateHealth,
                      useVerticalLayout: useVerticalLayout,
                    ),
                    const SizedBox(height: 24),
                    ExperienceSection(
                      value: _character.experience,
                      onChanged: _updateExperience,
                    ),
                    const SizedBox(height: 24),
                    NotesSection(
                      key: ValueKey(
                        '${_character.id}-$_isEditing-${identityHashCode(_character)}',
                      ),
                      sharedNotes: _character.storytellerNotes,
                      privateNotes: _character.storytellerPrivateNotes,
                      isStorytellerMode: _storytellerMode,
                      isEditing: _isEditing,
                      onChanged: _updateNotes,
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'Атрибуты: 7/5/3 • Способности: 13/9/5 • Дисциплины: 3 • и т.д.',
                        style: TextStyle(color: sheetTheme.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          );
        },
      ),
    );
  }
}
