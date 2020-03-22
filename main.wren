var DEBUG = false

import "graphics" for Canvas, Color
import "random" for Random
import "dome" for Window, Process
import "math" for M, Vec
import "input" for Keyboard
import "audio" for AudioEngine
import "io" for FileSystem
import "./keys" for Key

var BIT_RATE = 44100

var R = Random.new()
var D_PI = Num.pi / 180

var LEFT_KEY = Key.new("left", false, -1)
var RIGHT_KEY = Key.new("right", false, 1)
var SPACE_KEY = Key.new("space", false, true)
var SAVE_KEY = Key.new("s", false, true)

var ZERO_KEY = Key.new("0", false, true)
var STOP_KEY = Key.new("backspace", false, true)
var PLAY_KEY = Key.new("return", false, true)
var BEAT_KEY = Key.new("=", false, -1)
var BACK_KEY = Key.new("-", true, -1)
var PLAY_LEVEL_KEY = Key.new("p", false, -1)

var CLEAR_KEY = Key.new("[", false, true)
var EDITOR_KEYS = [
  Key.new("tab", false, -1),
  Key.new("1", false, 0),
  Key.new("2", false, 1),
  Key.new("3", false, 2)
]

class Level {
  clear() { _level = {} }
  beats { _level }
  bpm { _bpm }
  file { _file }
  construct load() {
    _level = {}
    var lines = FileSystem.load("level.dat").split("\n")
    var tokens = lines[0].split(" ")
    if (tokens[0] == "FILE") {
      _file = tokens[1]
    }
    tokens = lines[1].split(" ")
    if (tokens[0] == "BPM") {
      _bpm = Num.fromString(tokens[1])
    }
    for (lineIndex in 2...lines.count) {
      var line = lines[lineIndex]
      tokens = line.split("=")
      if (tokens.count == 2) {
        var beatNo = Num.fromString(tokens[0])
        if (!_level[beatNo]) {
          _level[beatNo] = [null, null, null]
        }
        for (i in 0...3) {
          var type = tokens[1][i]
          if (type == "S") {
            _level[beatNo][i] = Beat.new(beatNo, i, true)
          } else if (type == "D") {
            _level[beatNo][i] = Beat.new(beatNo, i, false)
          }
        }
      }
    }
  }
  reset() {
    for (row in beats.values) {
      for (beat in row) {
        if (beat != null) {
          beat.reset()
        }
      }
    }
  }
  save() {
    var lines = []
    var fileName = "race-to-mars.ogg"
    lines.add("FILE %(fileName)")
    lines.add("BPM %(_bpm)")
    for (beatNo in _level.keys) {
      var beats = _level[beatNo]
      var line = "%(beatNo)="
      for (beat in beats) {
        if (beat != null) {
          if (beat.safe) {
            line = line + "S"
          } else {
            line = line + "D"
          }
        } else {
          line = line + " "
        }
      }
      lines.add(line)
    }
    System.print(lines.join("\n"))
    FileSystem.save("level.dat", lines.join("\n"))
  }
}

class LevelEditor {
  construct new() {
    _mode = true
    _beat = 0
    _conductor = Conductor.new()
    _level = Level.load()
    _beats = _level.beats
    _counter = 0
  }


  level { _beats }
  stop() {
    _conductor.stop()
  }

  update() {
    _counter = M.max(0, _counter - 1)
    if (CLEAR_KEY.update()) {
      _level.clear()
      _beats = _level.beats
    }
    if (BEAT_KEY.update()) {
      _conductor.playBeat(_conductor.beatPosition)
      _level.reset()
    }
    if (BACK_KEY.update()) {
      _conductor.beatPosition = (_conductor.beatPosition - 1).round
      _conductor.update()
    }
    if (PLAY_KEY.update()) {
      _level.reset()
      _conductor.play()
    }
    if (PLAY_LEVEL_KEY.update()) {
      _level.reset()
      _conductor.beatPosition = 0
      _conductor.play()
    }
    if (STOP_KEY.update()) {
      _conductor.stop()
    }
    if (ZERO_KEY.update()) {
      for (row in _beats.values) {
        for (beat in row) {
          if (beat != null) {
            beat.reset()
          }
        }
      }
      _conductor.beatPosition = 0
      _conductor.stop()
    }
    _beat = _conductor.beatPosition.round
    EDITOR_KEYS.each {|key|
      if (key.update()) {
        if (key.action >= 0) {
          if (!_beats.containsKey(_beat)) {
            _beats[_beat] = [null, null, null]
          }
          if (_beats[_beat][key.action] == null) {
            _beats[_beat][key.action] = Beat.new(_beat, key.action, !!_mode)
          } else {
            _beats[_beat][key.action] = null
          }
        } else {
          _mode = !_mode
        }
      }
    }
    if (SAVE_KEY.update()) {
      _counter = 30
      save()
    }
  }

  draw() {
      var height = 17
      var lineY = Canvas.height - height / 2 - 12
    var start = _conductor.beatPosition
    for (l in -1...4) {
      var beatPos = l - (start - start.floor)
      var height = lineY - beatPos * 15
      Canvas.line(0, height, Canvas.width, height, Color.orange)
    }
    var left = Canvas.width - (8 * _beat.toString.count)
    Canvas.print(_beat, left, 0, Color.white)
    if (_mode) {
      Canvas.print("PICKUP", left - 8 * 7, 0, Color.green)
    } else {
      Canvas.print("DODGE", left - 8 * 6, 0, Color.red)
    }
    if (_counter > 0) {
      Canvas.print("Saved", Canvas.width - 5 * 8, 8, Color.orange)
    }
  }

  save() {
    _level.save()
  }

  conductor { _conductor }

}


class Beat {
  construct new(position, action) {
    _safe = true
    _position = position
    _action = action
    _hit = false
    _miss = false
  }

  reset() {
    _hit = false
    _miss = false
  }

  construct new(position, action, safe) {
    _safe = safe
    _position = position
    _action = action
    _hit = false
    _miss = false
  }

  hit() {
    _hit = true
  }
  miss() {
    _miss = true
  }

  safe { _safe }
  hit { _hit }
  miss { _miss }
  action { _action }
  position { _position }
}

var DebugLevel = Fn.new {
  var level = {}
  var side = 1
  for (n in 3...100) {
    var q = n * 4
    side = R.int(3)
    level[q] = [Beat.new(q, 0, false), Beat.new(q, 1, false), Beat.new(q, 2, false)]
    level[q][side] = Beat.new(q, side)
  }
  return level
}



class Song {
  construct new() {}
}

class Conductor {
  construct new() {
    _bpm = 160
    _crotchet = 60 / _bpm //sec per beat
    _position = 0
    _beatPosition = 0
    _audio = null
    _length = 0
    _playing = false
  }

  playing { _playing }
  construct new(audio) {
    _bpm = 160
    _crotchet = 60 / _bpm //sec per beat
    _position = 0
    _beatPosition = 0
    _audio = audio
    _length = audio.length / BIT_RATE
    _playing = true
  }

  play() {
    if (!_audio) {
      var channel = AudioEngine.play("music")
      channel.position = BIT_RATE * _crotchet * _beatPosition
      _audio = channel
      _length = _audio.length / BIT_RATE
      update()
      _playing = true
    }
  }

  playBeat(n) {

    n = M.max(0, n.round - 0.05)
    stop()
    var channel = AudioEngine.play("music")
    channel.position = BIT_RATE * _crotchet * n
    _audio = channel
    _beatPosition = n
    _position = n * _crotchet
    _length = (n + 1) * _crotchet
    _playing = true
  }

  update() {
    if (_audio) {
      _position = M.mid(0, (_audio.position / BIT_RATE), _length) // position in seconds
      _beatPosition = _position / _crotchet
      if (_position >= _length) {
        _position = _length
        stop()
      }
    }
  }
  stop() {
    if (_audio) {
      _playing = false
      _audio.stop()
      _audio = null
    }
  }

  position { _position }
  length { _length }
  beatPosition { _beatPosition }
  beatPosition=(v) {
    _beatPosition = M.max(0, v)
    _position = _beatPosition * _crotchet
  }
  bpm { _bpm }
}

class Decoration {
  update() {}
  draw(n) {}
}

var COLS = [
  Color.white,
  Color.darkgray
]

class SpaceLine is Decoration {
  construct new(pos, dir) {
    _original = pos
    _pos = pos
    _dir = dir.unit
    _len = 0
    _color = R.sample(COLS)
  }

  update() {
    if (_pos.x < 0 || _pos.x >= Canvas.width || _pos.y < 0 || _pos.y >= Canvas.height) {
      _pos = _original
      var theta = (-90 + R.int(280) - 140) * D_PI
      _dir = Vec.new(M.cos(theta), M.sin(theta))
    } else {
      _pos = _pos + _dir * 2
    }
    _len = M.mid(0, _len + 1, 40)
  }

  draw(n) {
    var dest = _pos + _dir * _len
    var color = _color
    /*
    if (_pos.y > (Canvas.height / 4) * 2) {
      color = _color
    }
    */
    Canvas.line(_pos.x, _pos.y, dest.x, dest.y, color)
  }

}

class RhythmGame {
   construct bootstrap() { /* Called by  DOME */ }
   construct begin(controller, args) {
     _controller = controller
     init()
   }
   init() {
      _editor = DEBUG ? LevelEditor.new() : null
      _shake = 0
      _shakePos = Vec.new()
      _flash = 0
      _charge = 5
      _score = 0
      _misses = 0
      _lives = 3
      _alive = true
      _oldX = 0
      _x = 0
      _tweenX = 0
      AudioEngine.load("music", "race-to-mars.ogg")

      if (_editor != null) {
        _conductor = _editor.conductor
      } else {
        _conductor = Conductor.new()
      }
      _lastBeat = 0

      var centerX = Canvas.width / 2
      var centerY = Canvas.height / 4
      var center = Vec.new(centerX, centerY)
      _decorations = (1...40).map {|n|
        var theta = (-90 + R.int(280) - 140) * D_PI
        return SpaceLine.new(center, Vec.new(M.cos(theta), M.sin(theta)))
      }.toList
      if (_editor != null) {
        _level = _editor.level
      } else {
        _level = Level.load().beats
        _conductor.play()
      }
      // DebugLevel.call()
    }
     update() {
      _alive = _lives > 0
      if (!_alive) {
        _controller.push(GameOverScene, [ _score ])
        _conductor.stop()
        return
      }
      if (_conductor.position >= _conductor.length) {
        __x = 0
        draw(0)
        _controller.push(WinScene, [ _score ])
        _conductor.stop()
        return
      }

      _beat = _conductor.beatPosition.floor
      if (_editor != null) {
        _editor.update()
        _level = _editor.level
        _conductor = _editor.conductor
      }
      _conductor.update()

      if (_shake > 0) {
        _shake = _shake - 1
        var magnitude = 6
        _shakePos = Vec.new(R.int(magnitude) - magnitude/2, R.int(magnitude) - magnitude / 2)
      } else {
        _shakePos = Vec.new()
      }
      _decorations.each {|decor| decor.update() }
      _tweenX = M.mid(0, _tweenX + 0.34, 1)
      LEFT_KEY.update()
      RIGHT_KEY.update()
      SPACE_KEY.update()

      // What if you can only move on the beat?
      var beatMargin = (_conductor.beatPosition - _beat).abs
      if (LEFT_KEY.firing) {
        _oldX = _x
        _tweenX = 0
        _x = _x + LEFT_KEY.action
      } else if (RIGHT_KEY.firing) {
        _oldX = _x
        _tweenX = 0
        _x = _x + RIGHT_KEY.action
      }

      _x = M.mid(-1, _x, 1)
      var notePosition = _x + 1
      if (_flash) {
        _flash = M.max(0, _flash - 1)
      }
      var soon = []
      ((_conductor.beatPosition.floor - 1)...(_conductor.beatPosition.floor + 2)).map {|n| _level[n] }.where{|a| a != null }.each {|beats| soon = soon + beats }
      var hit = false
      for (beat in soon) {
        if (beat != null) {
          var margin = (beat.position - _conductor.beatPosition)
          var absMargin = margin.abs
          if (!beat.hit && absMargin < 0.5 && beat.action == notePosition) {
            if (SPACE_KEY.firing && beat.safe) {
              System.print(margin)
              hit = true
              beat.hit()
              if (_conductor.playing && absMargin < 0.1) {
                _score = _score + 5
                _charge = _charge + 1
                _flash = 3
              } else if (_conductor.playing && absMargin < 0.3) {
                _score = _score + 3
                _charge = _charge + 1
                _flash = 3
              } else if (absMargin < 0.5) {
                _score = _score + 1
                _charge = _charge + 1
                _flash = 3
              }
            } else if (!beat.safe && absMargin < 0.1) {
              beat.hit()
              _shake = 5
              // _charge = M.max(0, _charge - 5)
              _lives = M.max(0, _lives - 1)
            }
          }
        }
        /*
        if (!hit && ) {
          _misses = _misses + 1
          _charge = M.max(0, _charge - 5)
        }
        */
      }
      for (beat in soon) {
        if (beat != null) {
          var margin = (beat.position - _conductor.beatPosition)
          if (margin < -1  && beat.safe && !beat.hit && !beat.miss) {
            beat.miss()
            _misses = _misses + 1
            _charge = M.max(0, _charge - 1)
          }
        }
      }
      _charge = M.mid(0, _charge, 5)

      if (_conductor.beatPosition.floor - _lastBeat == 1 && _conductor.playing) {
        _lastBeat = _conductor.beatPosition.floor
        // _charge = M.max(0, _charge - 1)
        if (_lives == 1) {
        }
      } else if (PLAY_KEY.firing || PLAY_LEVEL_KEY.firing) {
        _lastBeat = _conductor.beatPosition.floor
      }

      if (_charge <= 0) {
        _dead = true
      }
    }

     serializeLevel() {
      var lines = []
      var fileName = "race-to-mars.ogg"
      lines.add("FILE %(fileName)")
      lines.add("BPM %(_conductor.bpm)")
      for (beatNo in _level.keys) {
        var beats = _level[beatNo]
        var line = "%(beatNo)="
        for (beat in beats) {
          if (beat != null) {
            if (beat.safe) {
              line = line + "S"
            } else {
              line = line + "D"
            }
          } else {
            line = line + " "
          }
        }
        lines.add(line)
      }
      System.print(lines.join("\n"))
      FileSystem.save("level.dat", lines.join("\n"))
    }

     draw(dt) {
      Canvas.offset(_shakePos.x, _shakePos.y)
      Canvas.cls()
      _decorations.each {|decor| decor.draw(dt) }

      var theta = 35.5

      var width = 60
      var height = 17
      var spacing = 32

      var centerX = Canvas.width / 2
      var centerY = Canvas.height / 4
      var center = Vec.new(centerX, centerY)

      var playerY = Canvas.height - 2 - height - 9

      var lineY = playerY + height / 2 - 1
      Canvas.line(0, lineY, Canvas.width, lineY, Color.purple)
      Canvas.line(centerX, centerY, centerX, Canvas.height, Color.white)
      Canvas.circlefill(center.x, center.y, 12, Color.white)
      var beatDiff = (_conductor.beatPosition - _conductor.beatPosition.floor).abs
      for (n in 1...6) {
        Canvas.circle(center.x, center.y, (12 + beatDiff * 4 * n).floor, n <= 3 ? Color.white : Color.lightgray)
      }
      var centerLeft = Vec.new(centerX - 4, centerY)
      var centerRight = Vec.new(centerX + 4, centerY)
      var centerTarget = Vec.new(centerX, lineY)
      var leftTarget = Vec.new(centerX - (width + spacing), lineY)
      var rightTarget = Vec.new(centerX + (width + spacing), lineY)
      centerLeft = center
      centerRight = center
      // Draw to edge of screen in same direction
      var result = leftTarget + (leftTarget - centerLeft)
      Canvas.line(centerLeft.x, centerLeft.y, result.x, result.y, Color.white)
      result = rightTarget + (rightTarget - centerRight)
      Canvas.line(centerRight.x, centerRight.y, result.x, result.y, Color.white)

      var soon = []
      ((_conductor.beatPosition.floor - 3)...(_conductor.beatPosition.floor + 10)).map {|n| _level[n] }.where{|n| n != null }.each {|beats| soon = soon + beats }
      for (beat in soon) {
        if (beat != null) {
          var beatPos = (beat.position - _conductor.beatPosition)
          var origin
          var angle
          if (beat.action == 0) {
            origin = centerLeft
            angle = theta
          } else if (beat.action == 1) {
            origin = center
            angle = 0
          } else if (beat.action == 2) {
            origin = centerRight
            angle = -theta
          }

          var x = center.x + M.sin(angle) * (114 - beatPos * 15)
          var pos = Vec.new()
          pos.x = M.round(x)
          pos.y = lineY - beatPos * 15
          if (pos.y >= origin.y) {
            var radius = M.mid(8, 9 - beatPos, 1)
            if (beat.safe) {
              if (beat.hit) {
                Canvas.circle(pos.x, pos.y, radius, Color.green)
              } else {
                Canvas.circlefill(pos.x, pos.y, radius, Color.green)
                Canvas.print("O", pos.x - 3, pos.y - 3, Color.black)
              }
            } else {
              if (beat.hit) {
                Canvas.circle(pos.x, pos.y, radius, Color.red)
              } else {
                Canvas.circlefill(pos.x, pos.y, radius, Color.red)
                Canvas.print("X", pos.x - 3, pos.y - 3, Color.black)
              }
            }
          }
        }
      }

      var x = M.lerp(_oldX, _tweenX, _x)

      var pX = centerX + x * (width + spacing) - (width / 2)
      if (_flash > 0) {
        Canvas.ellipsefill(pX, playerY, pX + width, playerY + height, _flash > 0 ? Color.white : Color.red)
      } else {
        var bg = Color.rgb(Color.red.r, Color.red.g, Color.red.b, 128)
        Canvas.ellipsefill(pX, playerY, pX + width, playerY + height, bg)
        Canvas.ellipse(pX, playerY, pX + width, playerY + height, _flash > 0 ? Color.white : Color.red)
      }

      var secs = _conductor.length - _conductor.position
      var mins = (secs / 60).floor
      secs = (secs % 60)
      var msecs = ((secs - secs.floor) * 10).toString[0]
      secs = secs.floor
      if (mins <= 9) {
        mins = "0%(mins)"
      }
      if (secs <= 9) {
        secs = "0%(secs)"
      }

      if (_charge > 0) {
        if (_lives == 1 || _charge == 1) {
          Canvas.offset(_shakePos.x, _shakePos.y)
        }
        var color = Color.green
        var charge = M.mid(0, _charge, 5) * 10
        Canvas.rectfill(center.x, 0, charge + 1, 8, color)
        Canvas.rectfill(center.x - charge, 0, charge, 8, color)
        Canvas.line(center.x - charge, 8, center.x + charge, 8, Color.white)
        var text = _charge.toString.count * 4
        Canvas.print(_charge, center.x - text, 0, Color.black)
        Canvas.offset()
      }

      Canvas.offset()
      Canvas.print("Time %(mins):%(secs):%(msecs)", 0, 0, Color.white)
      Canvas.print("Score: %(_score)", 0, 8, Color.white)
      Canvas.print("Misses: %(_misses)", 0, 16, Color.white)
      Canvas.print("Lives: %(_lives)", 0, 24, Color.white)

      if (_editor != null) {
        _editor.draw()
      }
    }
}

class Game {
  static init() {
    var scale = 3
    Canvas.resize(320, 180)
    Window.resize(scale * Canvas.width, scale * Canvas.height)
    // __scene = RhythmGame.begin(this, [])
    push(TitleScene)
  }

  static update() {
    if (!DEBUG && Keyboard.isKeyDown("escape")) {
      Process.exit()
    }
    __scene.update()
  }

  static push(scene) { push(scene, []) }
  static push(scene, args) {
    __scene = scene.begin(this, args)
  }

  static draw(n) {
    __scene.draw(n)
  }
}

class GameOverScene {
  construct begin(controller, args) {
    _controller = controller
    _score = args[0]
    _size = 0
    _grow = Fiber.new {
      while (_size < Canvas.width * 3 / 4) {
        _size = _size + 1
        Fiber.yield(false)
      }
      return true
    }
  }
  update() {
    if (!_grow || _grow.call()) {
      _grow = null
      if (SPACE_KEY.update()) {
        _controller.push(RhythmGame)
      }
    } else {
    }
  }

  draw(alpha) {
    if (_grow) {
      Canvas.circlefill(Canvas.width / 2, Canvas.height / 4, _size, Color.red)
    } else {
      Canvas.cls(Color.red)
    }
    printCenter("GAME OVER", Canvas.height / 4 - 4, Color.black)
    printCenter("Your ship lost the beat", Canvas.height / 4 + 12, Color.black)
    printCenter("Press SPACE to try again", Canvas.height - 12, Color.black)
  }

  printCenter(text, y, color) {
    Canvas.print(text, Canvas.width / 2 - 4 * (text.count), y, color)
  }
}
class WinScene {
  construct begin(controller, args) {
    _controller = controller
    _score = args[0]
    _size = 0
    _grow = Fiber.new {
      while (_size < Canvas.width * 3 / 4) {
        _size = _size + 1
        Fiber.yield(false)
      }
      return true
    }
  }
  update() {
    if (!_grow || _grow.call()) {
      _grow = null
      if (SPACE_KEY.update()) {
        _controller.push(RhythmGame)
      }
    } else {
    }
  }

  draw(alpha) {
    if (_grow) {
      Canvas.circlefill(Canvas.width / 2, Canvas.height / 4, _size, Color.white)
    } else {
      Canvas.cls(Color.white)
    }
    printCenter("SUCCESS!", Canvas.height / 4 - 4, Color.black)
    printCenter("Great Navigation", Canvas.height / 4 + 12, Color.black)
    printCenter("You kept to the beat", Canvas.height / 4 + 20, Color.black)
    printCenter("Press SPACE to try again", Canvas.height - 12, Color.black)
  }

  printCenter(text, y, color) {
    Canvas.print(text, Canvas.width / 2 - 4 * (text.count), y, color)
  }
}

class TitleScene {
  construct begin(controller, args) {
    _controller = controller
    _position = 0
  }
  update() {
  }

  draw(alpha) {
    Canvas.cls(Color.black)
    var theta = 35.5

    var width = 60
    var height = 17
    var spacing = 32

    var centerX = Canvas.width / 2
    var centerY = Canvas.height / 4
    var center = Vec.new(centerX, centerY)

    var playerY = Canvas.height - 2 - height - 9

    var lineY = playerY + height / 2 - 1
    Canvas.line(0, lineY, Canvas.width, lineY, Color.purple)
    Canvas.line(centerX, centerY, centerX, Canvas.height, Color.white)
    Canvas.circlefill(center.x, center.y, 12, Color.white)
    var centerLeft = Vec.new(centerX - 4, centerY)
    var centerRight = Vec.new(centerX + 4, centerY)
    var centerTarget = Vec.new(centerX, lineY)
    var leftTarget = Vec.new(centerX - (width + spacing), lineY)
    var rightTarget = Vec.new(centerX + (width + spacing), lineY)
    centerLeft = center
    centerRight = center
    // Draw to edge of screen in same direction
    var result = leftTarget + (leftTarget - centerLeft)
    Canvas.line(centerLeft.x, centerLeft.y, result.x, result.y, Color.white)
    result = rightTarget + (rightTarget - centerRight)
    Canvas.line(centerRight.x, centerRight.y, result.x, result.y, Color.white)
    var x = 0

    var bg = Color.rgb(Color.red.r, Color.red.g, Color.red.b, 128)
    var pX = centerX + x * (width + spacing) - (width / 2)
    Canvas.ellipsefill(pX, playerY, pX + width, playerY + height, bg)
    Canvas.ellipse(pX, playerY, pX + width, playerY + height, Color.red)
  }


  printCenter(text, y, color) {
    Canvas.print(text, Canvas.width / 2 - 4 * (text.count), y, color)
  }
}
