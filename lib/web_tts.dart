import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class TtsVoice {
  final String name;
  final String lang;

  TtsVoice({required this.name, required this.lang});
}

class WebTts {
  final web.SpeechSynthesis _synth = web.window.speechSynthesis;
  List<TtsVoice> _voices = [];
  Completer<void>? _speakCompleter;

  Function? onStart;
  Function? onComplete;
  Function(String)? onError;

  List<TtsVoice> get voices => _voices;
  bool get isSpeaking => _synth.speaking;

  Future<void> init() async {
    _loadVoices();

    _synth.onvoiceschanged = (() {
      _loadVoices();
    }).toJS;

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      _loadVoices();
      if (getChineseVoices().isNotEmpty) break;
    }
  }

  void _loadVoices() {
    try {
      final jsVoices = _synth.getVoices().toDart;
      _voices = jsVoices.map((v) => TtsVoice(name: v.name, lang: v.lang)).toList();
    } catch (_) {}
  }

  List<TtsVoice> getChineseVoices() {
    return _voices.where((v) => v.lang.startsWith('zh')).toList();
  }

  Future<void> speak(
    String text, {
    TtsVoice? voice,
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
  }) {
    stop();

    final completer = Completer<void>();
    _speakCompleter = completer;

    final utterance = web.SpeechSynthesisUtterance(text);
    utterance.rate = rate;
    utterance.pitch = pitch;
    utterance.volume = volume;

    if (voice != null) {
      final jsVoices = _synth.getVoices().toDart;
      for (var v in jsVoices) {
        if (v.name == voice.name && v.lang == voice.lang) {
          utterance.voice = v;
          break;
        }
      }
    } else {
      utterance.lang = 'zh-CN';
    }

    utterance.onstart = (() {
      onStart?.call();
    }).toJS;

    utterance.onend = (() {
      if (!completer.isCompleted) {
        completer.complete();
      }
      onComplete?.call();
    }).toJS;

    utterance.onerror = (() {
      if (!completer.isCompleted) {
        completer.completeError('TTS Error');
      }
      onError?.call('TTS Error');
    }).toJS;

    _synth.speak(utterance);

    return completer.future;
  }

  void stop() {
    _synth.cancel();
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
    _speakCompleter = null;
  }

  void pause() => _synth.pause();
  void resume() => _synth.resume();
}
