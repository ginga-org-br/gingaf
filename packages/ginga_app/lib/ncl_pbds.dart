import 'ncl_document.dart';

class NclPBDS {
  static const String stateOpen = 'open';
  static const String stateActive = 'active';
  static const String stateClosed = 'closed';

  final String id;
  Uri? baseUri;
  String state;
  bool isPersistent;
  final Map<String, NclDocument> _documents = {};
  final Map<String, NclPBDS> _bases = {};

  String get baseId => id;

  NclPBDS({
    required this.id,
    this.baseUri,
    this.state = stateActive,
    this.isPersistent = false,
  }) {
    _bases[id] = this;
  }

  Map<String, NclDocument> get documents => Map.unmodifiable(_documents);

  Map<String, NclPBDS> get bases => Map.unmodifiable(_bases);

  List<String> get baseIds => List.unmodifiable(_bases.keys);

  NclPBDS? getBase([String? baseId]) {
    final cleanId = baseId?.trim() ?? '';
    if (cleanId.isEmpty || cleanId == id) {
      return this;
    }
    return _bases[cleanId];
  }

  NclPBDS openBase({
    String? baseId,
    Uri? baseUri,
    bool isPersistent = false,
  }) {
    final targetId =
        (baseId != null && baseId.trim().isNotEmpty) ? baseId.trim() : id;
    final existing = _bases[targetId];
    if (existing != null) {
      existing.open(baseUri: baseUri, isPersistent: isPersistent);
      return existing;
    }
    final created = NclPBDS(
      id: targetId,
      baseUri: baseUri,
      state: stateOpen,
      isPersistent: isPersistent,
    );
    _bases[targetId] = created;
    return created;
  }

  bool closeBase([String? baseId]) {
    final target = getBase(baseId);
    if (target == null) return false;
    target.close();
    if (!target.isPersistent && target.id != id) {
      final removed = _bases.remove(target.id);
      removed?.dispose();
    }
    return true;
  }

  void open({
    Uri? baseUri,
    bool isPersistent = false,
  }) {
    if (baseUri != null) {
      this.baseUri = baseUri;
    }
    if (isPersistent) {
      this.isPersistent = true;
    }
    state = stateOpen;
  }

  void activate() {
    state = stateActive;
  }

  void deactivate() {
    state = stateOpen;
  }

  void save() {
    isPersistent = true;
  }

  void close() {
    state = stateClosed;
  }

  NclDocument addDocument(
    String docId, {
    NclDocument? document,
    String? uri,
    String? content,
  }) {
    if (document != null) {
      _documents[docId] = document;
      return document;
    }
    final xml = (content != null && content.trim().isNotEmpty)
        ? content
        : '<ncl id="$docId"><body/></ncl>';
    final created = NclDocument.fromContent(
      xml,
      applicationId: docId,
      appSrc: (uri != null && uri.isNotEmpty) ? uri : docId,
    );
    _documents[docId] = created;
    return created;
  }

  bool removeDocument(String docId) => _documents.remove(docId) != null;

  NclDocument? getDocument(String docId) => _documents[docId];

  static String documentState(NclDocument doc) {
    final bodyState = doc.getBodyState();
    if (bodyState == NclStateType.sleeping) {
      return 'sleeping';
    }
    if (doc.isPaused || bodyState == NclStateType.paused) {
      return 'paused';
    }
    return 'occurring';
  }

  static Map<String, dynamic> documentToMap(NclDocument doc) => {
        'id': doc.applicationId,
        'uri': doc.docSrc,
        'state': documentState(doc),
      };

  void dispose() {
    for (final base in _bases.values) {
      if (!identical(base, this)) {
        base._documents.clear();
        base.state = stateClosed;
      }
    }
    _bases.clear();
    _documents.clear();
    state = stateClosed;
  }

  Map<String, dynamic> toMetadataMap() => {
        'baseId': id,
        'state': state,
        'persistent': isPersistent,
        'baseUri': baseUri?.toString() ?? '',
        'documents': _documents.values.map(documentToMap).toList(),
      };
}
