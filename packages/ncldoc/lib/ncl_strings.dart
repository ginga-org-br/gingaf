class NclKeys {
  static const String cursorDown = 'CURSOR_DOWN';
  static const String cursorLeft = 'CURSOR_LEFT';
  static const String cursorRight = 'CURSOR_RIGHT';
  static const String cursorUp = 'CURSOR_UP';

  static const String menu = 'MENU';
  static const String info = 'INFO';
  static const String guide = 'GUIDE';

  static const String channelDown = 'CHANNEL_DOWN';
  static const String channelUp = 'CHANNEL_UP';
  static const String volumeDown = 'VOLUME_DOWN';
  static const String volumeUp = 'VOLUME_UP';

  static const String enter = 'ENTER';
  static const String red = 'RED';
  static const String green = 'GREEN';
  static const String yellow = 'YELLOW';
  static const String blue = 'BLUE';

  static const String back = 'BACK';
  static const String exit = 'EXIT';
  static const String power = 'POWER';
  static const String rewind = 'REWIND';
  static const String stop = 'STOP';
  static const String eject = 'EJECT';
  static const String play = 'PLAY';
  static const String record = 'RECORD';
  static const String pause = 'PAUSE';

  static const String search = 'SEARCH';
  static const String favorite = 'FAVORITE';
  static const String playPause = 'PLAY_PAUSE';
  static const String fastForward = 'FAST_FORWARD';
  static const String audioDescription = 'AUDIO_DESCRIPTION';
  static const String closedCaptioning = 'CLOSED_CAPTIONING';
  static const String closedSigning = 'CLOSED_SIGNING';
  static const String dialogEnhancement = 'DIALOG_ENHANCEMENT';
  static const String audioSettings = 'AUDIO_SETTINGS';

  static const Set<String> cursorKeys = {
    cursorDown,
    cursorLeft,
    cursorRight,
    cursorUp,
  };

  static const Set<String> allKeys = {
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '*',
    '#',
    menu,
    info,
    guide,
    search,
    favorite,
    cursorDown,
    cursorLeft,
    cursorRight,
    cursorUp,
    channelDown,
    channelUp,
    volumeDown,
    volumeUp,
    enter,
    red,
    green,
    yellow,
    blue,
    back,
    exit,
    power,
    rewind,
    stop,
    eject,
    play,
    record,
    pause,
    playPause,
    fastForward,
    audioDescription,
    closedCaptioning,
    closedSigning,
    dialogEnhancement,
    audioSettings,
  };

  static bool isCursorKey(String key) {
    return cursorKeys.contains(normalizeKey(key));
  }

  static bool isValidKey(String key) {
    return allKeys.contains(normalizeKey(key));
  }

  static String normalizeKey(String key) {
    final upper = key.toUpperCase();
    switch (upper) {
      case 'UP':
        return cursorUp;
      case 'DOWN':
        return cursorDown;
      case 'LEFT':
        return cursorLeft;
      case 'RIGHT':
        return cursorRight;
      case 'OK':
      case 'SELECT':
        return enter;
      case 'PLAY/PAUSE':
      case 'PLAYPAUSE':
        return playPause;
      case 'FAST_FORWARD':
      case 'FASTFORWARD':
      case 'FF':
        return fastForward;
      default:
        return upper;
    }
  }
}
