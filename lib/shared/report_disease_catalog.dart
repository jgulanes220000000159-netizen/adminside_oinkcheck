const List<String> reportDiseaseKeys = [
  'bacterial erysipelas',
  'greasy pig disease',
  'sunburn',
  'ringworm',
  'mange',
  'foot and mouth disease',
  'swine pox',
];

String normalizeReportDiseaseName(String name) {
  final normalized =
      name
          .toLowerCase()
          .replaceAll(RegExp(r'[_\-]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  switch (normalized) {
    case '':
      return '';
    case 'healthy':
      return 'healthy';
    case 'erysipelas':
    case 'bacterial erysipelas':
    case 'infected bacterial erysipelas':
      return 'bacterial erysipelas';
    case 'greasy pig disease':
    case 'infected bacterial greasy':
    case 'bacterial greasy':
      return 'greasy pig disease';
    case 'sunburn':
    case 'infected environmental sunburn':
    case 'environmental sunburn':
      return 'sunburn';
    case 'ringworm':
    case 'infected fungal ringworm':
    case 'fungal ringworm':
      return 'ringworm';
    case 'mange':
    case 'infected parasitic mange':
    case 'parasitic mange':
      return 'mange';
    case 'foot and mouth disease':
    case 'infected viral foot and mouth':
    case 'infected viral foot and mouth disease':
      return 'foot and mouth disease';
    case 'swine pox':
    case 'swinepox':
      return 'swine pox';
    case 'dermatatis':
    case 'dermatitis':
      return 'dermatitis';
    case 'pityriasis rosea':
      return 'pityriasis rosea';
    case 'tip burn':
    case 'tipburn':
      return 'tip burn';
    case 'unknown':
      return 'unknown';
    default:
      return normalized;
  }
}

bool isExcludedReportDisease(String name) {
  final normalized = normalizeReportDiseaseName(name);
  return normalized == 'dermatitis' || normalized == 'pityriasis rosea';
}

bool isIgnoredReportDisease(String name) {
  final normalized = normalizeReportDiseaseName(name);
  return normalized.isEmpty ||
      normalized == 'unknown' ||
      normalized == 'tip burn';
}

List<String> orderedReportDiseaseKeys({Iterable<String> observed = const []}) {
  final ordered = [...reportDiseaseKeys];
  final seen = {...ordered};

  for (final rawName in observed) {
    final normalized = normalizeReportDiseaseName(rawName);
    if (normalized.isEmpty ||
        normalized == 'healthy' ||
        isIgnoredReportDisease(normalized) ||
        isExcludedReportDisease(normalized)) {
      continue;
    }
    if (seen.add(normalized)) {
      ordered.add(normalized);
    }
  }

  return ordered;
}

String reportDiseaseDisplayName(String name) {
  switch (normalizeReportDiseaseName(name)) {
    case 'healthy':
      return 'Healthy';
    case 'bacterial erysipelas':
      return 'Bacterial Erysipelas';
    case 'greasy pig disease':
      return 'Greasy Pig Disease';
    case 'sunburn':
      return 'Sunburn';
    case 'ringworm':
      return 'Ringworm';
    case 'mange':
      return 'Mange';
    case 'foot and mouth disease':
      return 'Foot-and-Mouth Disease';
    case 'swine pox':
      return 'Swine Pox';
    case 'dermatitis':
      return 'Dermatitis';
    case 'pityriasis rosea':
      return 'Pityriasis Rosea';
    case 'tip burn':
      return 'Tip Burn';
    case 'unknown':
      return 'Unknown';
    default:
      return _titleCase(name);
  }
}

String _titleCase(String input) {
  if (input.isEmpty) return input;
  return input
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}
