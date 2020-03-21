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
var SAVE_KEY = Key.new("return", false, true)

var ZERO_KEY = Key.new("0", false, true)
var STOP_KEY = Key.new("backspace", false, true)
var PLAY_KEY = Key.new("-", false, true)
var BEAT_KEY = Key.new("=", false, -1)
var PLAY_LEVEL_KEY = Key.new("p", false, -1)

var CLEAR_KEY = Key.new("[", false, true)
var EDITOR_KEYS = [
  Key.new("tab", false, -1),
  Key.new("1", false, 0),
  Key.new("2", false, 1),
  Key.new("3", false, 2)
]

class LevelEditor {
  construct new() {
    _level = {}
    _mode = true
    _beat = 0
    _conductor = Conductor.new()
    load()
  }


  level { _level }
  stop() {
    _conductor.stop()
  }

  update() {
    if (CLEAR_KEY.update()) {
      _level = {}
    }
    if (BEAT_KEY.update()) {
      _conductor.playBeat(_conductor.beatPosition + 1)
    }
    if (PLAY_KEY.update()) {
      _conductor.play()
    }
    if (STOP_KEY.update()) {
      _conductor.stop()
    }
    if (ZERO_KEY.update()) {
      for (row in _level.values) {
        for (beat in row) {
          if (beat != null) {
            beat.reset()
          }
        }
      }
      _conductor.beatPosition = 0
      _conductor.stop()
    }
    _beat = _conductor.beatPosition.floor
    EDITOR_KEYS.each {|key|
      if (key.update()) {
        if (key.action >= 0) {
          if (!_level.containsKey(_beat)) {
            _level[_beat] = [null, null, null]
          }
          if (_level[_beat][key.action] == null) {
            _level[_beat][key.action] = Beat.new(_beat, key.action, !!_mode)
          } else {
            _level[_beat][key.action] = null
          }
        } else {
          _mode = !_mode
        }
      }
    }
    if (SAVE_KEY.update()) {
      save()
    }
  }

  draw() {
    var left = Canvas.width - (8 * _beat.toString.count)
    Canvas.print(_beat, left, 0, Color.white)
    if (_mode) {
      Canvas.print("PICKUP", left - 8 * 7, 0, Color.green)
    } else {
      Canvas.print("DODGE", left - 8 * 6, 0, Color.red)

    }
  }

  load() {
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

  save() {
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
  }
  construct new(audio) {
    _bpm = 160
    _crotchet = 60 / _bpm //sec per beat
    _position = 0
    _beatPosition = 0
    _audio = audio
    _length = audio.length / BIT_RATE
  }

  play() {
    if (!_audio) {
      var channel = AudioEngine.play("music")
      channel.position = BIT_RATE * _crotchet * _beatPosition
      _audio = channel
      _length = _audio.length / BIT_RATE
      update()
    }
  }

  playBeat(n) {
    n = n.floor - 0.05
    if (_audio) {
      _audio.stop()
      _audio = null
    }
    var channel = AudioEngine.play("music")
    channel.position = BIT_RATE * _crotchet * n
    _audio = channel
    _beatPosition = n
    _position = n * _crotchet
    _length = (n + 1) * _crotchet
  }


  update() {
    if (_audio) {
      _position = M.mid(0, (_audio.position / BIT_RATE), _length) // position in seconds
      _beatPosition = _position / _crotchet
      if (_position >= _length) {
        _position = _length
        _audio.stop()
        _audio = null
      }
    }
  }
  stop() {
    if (_audio) {
      _audio.stop()
      _audio = null
    }
  }

  position { _position }
  length { _length }
  beatPosition { _beatPosition }
  beatPosition=(v) { _beatPosition = v }
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

class Game {
    static init() {
      __editor = LevelEditor.new()
      __shake = 0
      __shadePos = 0
      __flash = 0
      __charge = 0
      __score = 0
      __misses = 0
      Canvas.resize(320, 180)
      Canvas.offset(5, 5)
      var scale = 3
      Window.resize(scale * Canvas.width, scale * Canvas.height)
      __oldX = 0
      __x = 0
      __tweenX = 0
      // AudioEngine.load("music", "extremeaction.ogg")
      // AudioEngine.load("music", "click.ogg")
      AudioEngine.load("music", "race-to-mars.ogg")
      // var channel = AudioEngine.play("music")
      // channel.position = BIT_RATE * 60
      // __conductor = Conductor.new(channel)
      /*
        var channel = AudioEngine.play("music")
        __conductor.stop()
        __conductor = Conductor.new(channel)
      */

      if (__editor != null) {
        __conductor = __editor.conductor
      } else {
        __conductor = Conductor.new()
      }

      var centerX = Canvas.width / 2
      var centerY = Canvas.height / 4
      var center = Vec.new(centerX, centerY)
      __decorations = (1...40).map {|n|
        var theta = (-90 + R.int(280) - 140) * D_PI
        return SpaceLine.new(center, Vec.new(M.cos(theta), M.sin(theta)))
      }.toList
      __level = __editor.level
      // DebugLevel.call()
    }
    static update() {
      __beat = __conductor.beatPosition.floor
      __editor.update()
      __level = __editor.level
      __conductor = __editor.conductor
      __conductor.update()

      if (__shake > 0) {
        __shake = __shake - 1
        var magnitude = 6
        __shakePos = Vec.new(R.int(magnitude) - magnitude/2, R.int(magnitude) - magnitude / 2)
      } else {
        __shakePos = Vec.new()
      }
      __decorations.each {|decor| decor.update() }
      __tweenX = M.mid(0, __tweenX + 0.34, 1)
      if (Keyboard.isKeyDown("escape")) {
        Process.exit()
      }
      if (PLAY_LEVEL_KEY.update()) {
        __editor.conductor.beatPosition = 0
        __editor.conductor.play()
      }
      LEFT_KEY.update()
      RIGHT_KEY.update()
      SPACE_KEY.update()

      if (LEFT_KEY.firing) {
        __oldX = __x
        __tweenX = 0
        __x = __x + LEFT_KEY.action
      } else if (RIGHT_KEY.firing) {
        __oldX = __x
        __tweenX = 0
        __x = __x + RIGHT_KEY.action
      }

      __x = M.mid(-1, __x, 1)
      var notePosition = __x + 1
      if (__flash) {
        __flash = M.max(0, __flash - 1)
      }
      var soon = []
      ((__conductor.beatPosition.floor - 1)...(__conductor.beatPosition.floor + 2)).map {|n| __level[n] }.where{|a| a != null }.each {|beats| soon = soon + beats }
      var hit = false
      for (beat in soon) {
        if (beat != null) {
          var margin = (beat.position - __conductor.beatPosition)
          var absMargin = margin.abs
          if (!beat.hit && absMargin < 0.5 && beat.action == notePosition) {
            if (SPACE_KEY.firing && beat.safe) {
              System.print(margin)
              hit = true
              beat.hit()
              if (absMargin < 0.1) {
                __score = __score + 5
                __charge = __charge + 3
                __flash = 3
              } else if (absMargin < 0.3) {
                __score = __score + 3
                __charge = __charge + 1
                __flash = 3
              } else if (absMargin < 0.5) {
                __score = __score + 1
                __flash = 3
              }
            } else if (!beat.safe && absMargin < 0.1) {
              beat.hit()
              __shake = 5
              __charge = M.max(0, __charge - 5)
              __misses = __misses + 1
            }
          }
        }
        /*
        if (!hit && ) {
          __misses = __misses + 1
          __charge = M.max(0, __charge - 5)
        }
        */
      }
      for (beat in soon) {
        if (beat != null) {
          var margin = (beat.position - __conductor.beatPosition)
          if (margin < -1  && beat.safe && !beat.hit && !beat.miss) {
            beat.miss()
            __misses = __misses + 1
            // __charge = M.max(0, __charge - 3)
          }
        }
      }
    }

    static serializeLevel() {
      var lines = []
      var fileName = "race-to-mars.ogg"
      lines.add("FILE %(fileName)")
      lines.add("BPM %(__conductor.bpm)")
      for (beatNo in __level.keys) {
        var beats = __level[beatNo]
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

    static draw(dt) {
      Canvas.offset(__shakePos.x, __shakePos.y)
      Canvas.cls()
      __decorations.each {|decor| decor.draw(dt) }

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
      var beatDiff = (__conductor.beatPosition - __conductor.beatPosition.floor).abs
      for (n in 0...5) {
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
      ((__conductor.beatPosition.floor - 3)...(__conductor.beatPosition.floor + 10)).map {|n| __level[n] }.where{|n| n != null }.each {|beats| soon = soon + beats }
      for (beat in soon) {
        if (beat != null) {
          var beatPos = (beat.position - __conductor.beatPosition)
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

      var x = M.lerp(__oldX, __tweenX, __x)

      var pX = centerX + x * (width + spacing) - (width / 2)
      if (__flash > 0) {
        Canvas.ellipsefill(pX, playerY, pX + width, playerY + height, __flash > 0 ? Color.white : Color.red)
      } else {
        var bg = Color.rgb(Color.red.r, Color.red.g, Color.red.b, 128)
        Canvas.ellipsefill(pX, playerY, pX + width, playerY + height, bg)
        Canvas.ellipse(pX, playerY, pX + width, playerY + height, __flash > 0 ? Color.white : Color.red)
      }

      var secs = __conductor.length - __conductor.position
      var mins = (secs / 60).floor
      secs = (secs % 60)
      var msecs = ((secs - secs.floor) * 10).toString[0]
      secs = secs.floor
      if (mins < 9) {
        mins = "0%(mins)"
      }
      if (secs < 9) {
        secs = "0%(secs)"
      }

      if (__charge > 0) {
        var color = Color.green
        Canvas.rectfill(center.x + 1, 0, __charge, 8, color)
        Canvas.rectfill(center.x - __charge, 0, __charge, 8, color)
        Canvas.line(center.x - __charge, 8, center.x + __charge, 8, Color.white)
      }

      Canvas.offset()
      Canvas.print("Score: %(__score)", 0, 0, Color.white)
      Canvas.print("Misses: %(__misses)", 0, 8, Color.white)
      Canvas.print("Time %(mins):%(secs):%(msecs)", 0, 16, Color.white)
      __editor.draw()
    }
}
